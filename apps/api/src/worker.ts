import './env';
import './monitoring';
import { setTimeout as sleep } from 'node:timers/promises';
import { createDb, mornings, rides, schedules } from '@app/db';
import { addDays, RIDES_KEPT_DAYS, today } from '@app/shared';
import { and, eq, inArray, lt, lte, sql } from 'drizzle-orm';
import { captureException } from './monitoring';

// Same image as the API, started with `bun apps/api/src/worker.ts`. The API runs
// the migrations. Deletes rides a week after their morning, as the booking page promises.
const db = createDb(process.env.DATABASE_URL);
const PURGE = 'purge-rides';
const stop = new AbortController();
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => stop.abort());

async function purge() {
  const cutoff = addDays(today(), -RIDES_KEPT_DAYS);
  const past = db.select({ id: mornings.id }).from(mornings).where(lt(mornings.date, cutoff));
  const deleted = await db.delete(rides).where(inArray(rides.morningId, past)).returning({ id: rides.id });
  if (deleted.length) console.log(`[worker] Deleted ${deleted.length} rides`);
}

// Moving next_run in the same statement claims the job, so with several
// workers only one runs it per hour.
async function claim(name: string) {
  const [due] = await db
    .update(schedules)
    .set({ nextRun: sql`now() + interval '1 hour'` })
    .where(and(eq(schedules.name, name), lte(schedules.nextRun, sql`now()`)))
    .returning({ name: schedules.name });
  return !!due;
}

// For the healthcheck in docker-compose.prod.yml
const server = Bun.serve({ port: Number(process.env.PORT || 3001), fetch: () => Response.json({ status: 'ok' }) });
console.log('[worker] Purging old rides every hour');

while (!stop.signal.aborted) {
  try {
    await db.insert(schedules).values({ name: PURGE }).onConflictDoNothing();
    if (await claim(PURGE)) await purge();
  } catch (err) {
    console.error('[worker] Purge failed:', err);
    captureException(err);
  }
  await sleep(60_000, undefined, { signal: stop.signal }).catch(() => {});
}

await server.stop();
await db.$client.end();
process.exit(0);
