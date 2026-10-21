import { mornings, practices, rides, teamKey } from '@app/db';
import { bookRideSchema, type RideStatus, today } from '@app/shared';
import { and, asc, count, eq, gt } from 'drizzle-orm';
import { Hono } from 'hono';
import { t } from '../lib/i18n';
import { clientIp, rateLimit, tooManyRequests } from '../lib/rate-limit';
import { validJson } from '../lib/validate';
import { generateToken, hashToken } from '../middleware/auth';
import type { AppEnv } from '../types';

const HOUR = 60 * 60 * 1000;
const bookingsPerIp = rateLimit('bookings-per-ip', 10, HOUR);
const tokenChecksPerIp = rateLimit('ride-tokens-per-ip', 60, HOUR);

// Bookable until the day before, the team calls the patient the evening before
const upcoming = () => gt(mornings.date, today());

// A patient cancels until the morning itself, as long as nobody is on the way
const cancellable = (ride: { status: RideStatus; date: string }) =>
  (ride.status === 'new' || ride.status === 'confirmed') && ride.date >= today();

// Patients book without an account. All they get back is a token to look at
// and cancel their ride; the details stay encrypted to the team.
export const rideRoutes = new Hono<AppEnv>()
  // Practice, its bookable mornings and the key to encrypt the booking to
  .get('/practices/:slug', async (c) => {
    const db = c.get('db');
    const [practice] = await db
      .select({ id: practices.id, slug: practices.slug, name: practices.name, address: practices.address })
      .from(practices)
      .where(eq(practices.slug, c.req.param('slug')));
    if (!practice) return c.json({ error: t(c).notFound }, 404);

    const list = await db
      .select({
        id: mornings.id,
        practiceId: mornings.practiceId,
        date: mornings.date,
        start: mornings.start,
        end: mornings.end,
        capacity: mornings.capacity,
        booked: count(rides.id),
      })
      .from(mornings)
      .leftJoin(rides, eq(rides.morningId, mornings.id))
      .where(and(eq(mornings.practiceId, practice.id), upcoming()))
      .groupBy(mornings.id)
      .orderBy(asc(mornings.date));
    const [key] = await db.select({ publicKey: teamKey.publicKey }).from(teamKey);
    return c.json({ practice, mornings: list, publicKey: key?.publicKey ?? null });
  })

  .post('/rides', validJson(bookRideSchema), async (c) => {
    if (!(await bookingsPerIp.hit(c, clientIp(c)))) return tooManyRequests(c);
    const { morningId, payload } = c.req.valid('json');
    const token = generateToken();

    // The row lock on the morning serialises bookings, so two patients can't
    // take the last seat at the same time.
    const booked = await c.get('db').transaction(async (tx) => {
      const [morning] = await tx
        .select({ capacity: mornings.capacity })
        .from(mornings)
        .where(and(eq(mornings.id, morningId), upcoming()))
        .for('update');
      if (!morning) return false;
      const [{ taken } = { taken: 0 }] = await tx
        .select({ taken: count() })
        .from(rides)
        .where(eq(rides.morningId, morningId));
      if (taken >= morning.capacity) return false;
      await tx.insert(rides).values({ morningId, payload, manageTokenHash: hashToken(token) });
      return true;
    });
    if (!booked) return c.json({ error: t(c).morningFull }, 409);
    return c.json({ token });
  })

  .get('/rides/:token', async (c) => {
    if (!(await tokenChecksPerIp.hit(c, clientIp(c)))) return tooManyRequests(c);
    const [ride] = await c
      .get('db')
      .select({
        status: rides.status,
        date: mornings.date,
        start: mornings.start,
        end: mornings.end,
        practice: practices.name,
        address: practices.address,
      })
      .from(rides)
      .innerJoin(mornings, eq(mornings.id, rides.morningId))
      .innerJoin(practices, eq(practices.id, mornings.practiceId))
      .where(eq(rides.manageTokenHash, hashToken(c.req.param('token'))));
    if (!ride) return c.json({ error: t(c).rideNotFound }, 404);
    return c.json({ ride: { ...ride, cancellable: cancellable(ride) } });
  })

  // Cancelling deletes the ride, nothing of it stays behind
  .delete('/rides/:token', async (c) => {
    if (!(await tokenChecksPerIp.hit(c, clientIp(c)))) return tooManyRequests(c);
    const db = c.get('db');
    const [ride] = await db
      .select({ id: rides.id, status: rides.status, date: mornings.date })
      .from(rides)
      .innerJoin(mornings, eq(mornings.id, rides.morningId))
      .where(eq(rides.manageTokenHash, hashToken(c.req.param('token'))));
    if (!ride) return c.json({ error: t(c).rideNotFound }, 404);
    if (!cancellable(ride)) return c.json({ error: t(c).rideNotCancellable }, 409);
    await db.delete(rides).where(eq(rides.id, ride.id));
    return c.json({ ok: true });
  });
