import { mornings, practices, rides, teamKey } from '@app/db';
import { morningSchema, practiceSchema, rideStatusSchema, teamKeySchema, today } from '@app/shared';
import { asc, count, eq, gte } from 'drizzle-orm';
import { Hono } from 'hono';
import { createMiddleware } from 'hono/factory';
import { z } from 'zod';
import { t } from '../lib/i18n';
import { validJson } from '../lib/validate';
import { requireAuth } from '../middleware/auth';
import type { AppEnv } from '../types';

// Anyone can log in, only the addresses in TEAM_EMAILS see rides
const teamEmails = () =>
  (process.env.TEAM_EMAILS ?? '')
    .split(',')
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean);

const inTeam = (email: string) => teamEmails().includes(email);

const requireTeam = createMiddleware<AppEnv>(async (c, next) => {
  if (!inTeam(c.get('user').email)) return c.json({ error: t(c).notInTeam }, 403);
  await next();
});

// Malformed ids would otherwise reach Postgres and fail there
const isId = (value: string) => z.uuid().safeParse(value).success;

const morningColumns = {
  id: mornings.id,
  practiceId: mornings.practiceId,
  date: mornings.date,
  start: mornings.start,
  end: mornings.end,
  capacity: mornings.capacity,
};

export const teamRoutes = new Hono<AppEnv>()
  // Lets the web tell logged-in outsiders apart without a failing request
  .get('/access', requireAuth, (c) => c.json({ team: inTeam(c.get('user').email) }))
  .use(requireAuth, requireTeam)

  .get('/key', async (c) => {
    const [key] = await c
      .get('db')
      .select({
        publicKey: teamKey.publicKey,
        encryptedPrivateKey: teamKey.encryptedPrivateKey,
        salt: teamKey.salt,
        iv: teamKey.iv,
        iterations: teamKey.iterations,
      })
      .from(teamKey);
    return c.json({ key: key ?? null });
  })

  // Set up once. Replacing the key would make every booked ride unreadable.
  .post('/key', validJson(teamKeySchema), async (c) => {
    const [created] = await c
      .get('db')
      .insert(teamKey)
      .values(c.req.valid('json'))
      .onConflictDoNothing()
      .returning({ id: teamKey.id });
    if (!created) return c.json({ error: t(c).keyExists }, 409);
    return c.json({ ok: true });
  })

  .get('/practices', async (c) => {
    const list = await c
      .get('db')
      .select({ id: practices.id, slug: practices.slug, name: practices.name, address: practices.address })
      .from(practices)
      .orderBy(asc(practices.name));
    return c.json({ practices: list });
  })

  .post('/practices', validJson(practiceSchema), async (c) => {
    const [practice] = await c
      .get('db')
      .insert(practices)
      .values(c.req.valid('json'))
      .onConflictDoNothing()
      .returning({ id: practices.id, slug: practices.slug, name: practices.name, address: practices.address });
    if (!practice) return c.json({ error: t(c).slugTaken }, 409);
    return c.json({ practice });
  })

  // Upcoming mornings and those of the past week, whose rides still exist
  .get('/mornings', async (c) => {
    const weekAgo = today(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000));
    const list = await c
      .get('db')
      .select({ ...morningColumns, booked: count(rides.id) })
      .from(mornings)
      .leftJoin(rides, eq(rides.morningId, mornings.id))
      .where(gte(mornings.date, weekAgo))
      .groupBy(mornings.id)
      .orderBy(asc(mornings.date));
    return c.json({ mornings: list });
  })

  .post('/mornings', validJson(morningSchema), async (c) => {
    const [morning] = await c
      .get('db')
      .insert(mornings)
      .values(c.req.valid('json'))
      .onConflictDoNothing()
      .returning(morningColumns);
    if (!morning) return c.json({ error: t(c).morningExists }, 409);
    return c.json({ morning: { ...morning, booked: 0 } });
  })

  .get('/mornings/:id/rides', async (c) => {
    const db = c.get('db');
    const id = c.req.param('id');
    if (!isId(id)) return c.json({ error: t(c).notFound }, 404);
    const [morning] = await db.select(morningColumns).from(mornings).where(eq(mornings.id, id));
    if (!morning) return c.json({ error: t(c).notFound }, 404);
    const list = await db
      .select({ id: rides.id, status: rides.status, payload: rides.payload, createdAt: rides.createdAt })
      .from(rides)
      .where(eq(rides.morningId, id))
      .orderBy(asc(rides.createdAt));
    return c.json({ morning, rides: list });
  })

  .patch('/rides/:id', validJson(rideStatusSchema), async (c) => {
    if (!isId(c.req.param('id'))) return c.json({ error: t(c).notFound }, 404);
    const [ride] = await c
      .get('db')
      .update(rides)
      .set({ status: c.req.valid('json').status })
      .where(eq(rides.id, c.req.param('id')))
      .returning({ id: rides.id, status: rides.status });
    if (!ride) return c.json({ error: t(c).notFound }, 404);
    return c.json({ ride });
  })

  .delete('/mornings/:id', async (c) => {
    const db = c.get('db');
    const id = c.req.param('id');
    if (!isId(id)) return c.json({ error: t(c).notFound }, 404);
    const [{ booked } = { booked: 0 }] = await db
      .select({ booked: count() })
      .from(rides)
      .where(eq(rides.morningId, id));
    if (booked > 0) return c.json({ error: t(c).morningHasRides }, 409);
    await db.delete(mornings).where(eq(mornings.id, id));
    return c.json({ ok: true });
  });
