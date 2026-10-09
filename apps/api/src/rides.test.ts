import { afterAll, beforeAll, expect, test } from 'bun:test';
import { createDb, migrateDb, mornings, practices, rides, sessions, teamKey, users } from '@app/db';
import { createTeamKey, today } from '@app/shared';
import { eq } from 'drizzle-orm';
import { createApp } from './app';
import { generateToken, hashToken } from './middleware/auth';

// Runs against DATABASE_URL and only adds its own practice, so the local dev database is safe to use.
const db = createDb(process.env.DATABASE_URL!);
const app = createApp(db);
const ip = crypto.randomUUID();
const slug = `test-${crypto.randomUUID().slice(0, 8)}`;
const inDays = (days: number) => today(new Date(Date.now() + days * 24 * 60 * 60 * 1000));

beforeAll(() => migrateDb(process.env.DATABASE_URL!));
afterAll(async () => {
  await db.delete(practices).where(eq(practices.slug, slug));
  await db.$client.end();
});

function request(method: string, path: string, body?: unknown, headers: Record<string, string> = {}) {
  return app.request(`/api/v1${path}`, {
    method,
    headers: { 'content-type': 'application/json', 'x-forwarded-for': ip, ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

// biome-ignore lint/suspicious/noExplicitAny: the tests check the shape with expect
async function body(res: Response | Promise<Response>): Promise<any> {
  return (await res).json();
}

async function session(email: string) {
  const [user] = await db.insert(users).values({ email, name: 'test' }).returning();
  const token = generateToken();
  await db.insert(sessions).values({
    userId: user!.id,
    tokenHash: hashToken(token),
    expiresAt: new Date(Date.now() + 60_000),
  });
  return { authorization: `Bearer ${token}` };
}

async function practiceWithMorning(capacity: number, date = inDays(3)) {
  const [practice] = await db
    .insert(practices)
    .values({ slug, name: 'Testpraxis', address: 'Teststraße 1, 79098 Freiburg' })
    .onConflictDoUpdate({ target: practices.slug, set: { name: 'Testpraxis' } })
    .returning();
  const [morning] = await db
    .insert(mornings)
    .values({ practiceId: practice!.id, date, start: '08:00', end: '12:00', capacity })
    .returning();
  return morning!;
}

const payload = 'v1.ZXBo.aXY=.Y2lwaGVy';
const TEST_PASSPHRASE = 'local test passphrase';

test('a patient books, looks at and cancels a ride without an account', async () => {
  const morning = await practiceWithMorning(4, inDays(5));
  const page = await body(request('GET', `/practices/${slug}`));
  expect(page.practice.name).toBe('Testpraxis');
  expect(page.mornings.map((m: { id: string }) => m.id)).toContain(morning.id);

  const booked = await request('POST', '/rides', { morningId: morning.id, payload });
  expect(booked.status).toBe(200);
  const { token } = await body(booked);

  const [stored] = await db.select().from(rides).where(eq(rides.morningId, morning.id));
  expect(stored!.payload).toBe(payload);
  expect(stored!.manageTokenHash).not.toBe(token);

  expect((await body(request('GET', `/rides/${token}`))).ride).toMatchObject({ status: 'new', practice: 'Testpraxis' });
  expect((await request('DELETE', `/rides/${token}`)).status).toBe(200);
  expect(await db.select().from(rides).where(eq(rides.morningId, morning.id))).toEqual([]);
  expect((await request('GET', `/rides/${token}`)).status).toBe(404);
});

test('a full morning takes no more bookings, even at the same time', async () => {
  const morning = await practiceWithMorning(2, inDays(6));
  const results = await Promise.all(
    [1, 2, 3, 4].map(() => request('POST', '/rides', { morningId: morning.id, payload })),
  );
  expect(results.map((r) => r.status).sort()).toEqual([200, 200, 409, 409]);
});

test('mornings of today and before take no bookings', async () => {
  const morning = await practiceWithMorning(4, today());
  expect((await request('POST', '/rides', { morningId: morning.id, payload })).status).toBe(409);
  const page = await body(request('GET', `/practices/${slug}`));
  expect(page.mornings.map((m: { id: string }) => m.id)).not.toContain(morning.id);
});

test('only team addresses see rides', async () => {
  const email = `test-${crypto.randomUUID()}@example.com`;
  const auth = await session(email);
  expect(await body(request('GET', '/team/access', undefined, auth))).toEqual({ team: false });
  expect((await request('GET', '/team/mornings', undefined, auth)).status).toBe(403);
  expect((await request('GET', '/team/mornings')).status).toBe(401);

  process.env.TEAM_EMAILS = `someone@example.com, ${email.toUpperCase()}`;
  const morning = await practiceWithMorning(4, inDays(7));
  await request('POST', '/rides', { morningId: morning.id, payload });
  const day = await body(request('GET', `/team/mornings/${morning.id}/rides`, undefined, auth));
  expect(day.rides).toEqual([expect.objectContaining({ status: 'new', payload })]);

  const changed = await request('PATCH', `/team/rides/${day.rides[0].id}`, { status: 'confirmed' }, auth);
  expect((await body(changed)).ride.status).toBe('confirmed');
  expect((await request('DELETE', `/team/mornings/${morning.id}`, undefined, auth)).status).toBe(409);
  expect((await request('GET', '/team/mornings/not-an-id/rides', undefined, auth)).status).toBe(404);
});

test('the team key is set up only once', async () => {
  const email = `test-${crypto.randomUUID()}@example.com`;
  const auth = await session(email);
  process.env.TEAM_EMAILS = email;
  // A real key: the web tests encrypt bookings to it. See AGENTS.md for the passphrase.
  await db
    .insert(teamKey)
    .values(await createTeamKey(TEST_PASSPHRASE))
    .onConflictDoNothing();
  const { key } = await body(request('GET', '/team/key', undefined, auth));
  expect(key.iterations).toBeGreaterThan(0);
  expect((await request('POST', '/team/key', key, auth)).status).toBe(409);
}, 30_000);
