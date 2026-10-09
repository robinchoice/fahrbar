import './monitoring';
import { createDb, mornings, rides, schedules } from '@app/db';
import { today } from '@app/shared';
import { and, eq, inArray, lt, lte, sql } from 'drizzle-orm';
import { captureException } from './monitoring';

// Same image as the API, started with `bun apps/api/src/worker.ts`. The API runs
// the migrations. Deletes rides a week after their morning, as the booking page promises.
const db = createDb(process.env.DATABASE_URL!);
const KEEP_DAYS = 7;
const PURGE = 'purge-rides';

async function purge() {
  const cutoff = today(new Date(Date.now() - KEEP_DAYS * 24 * 60 * 60 * 1000));
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
Bun.serve({ port: Number(process.env.PORT || 3001), fetch: () => Response.json({ status: 'ok' }) });
console.log('[worker] Purging old rides every hour');

// A purge is one statement, a stop in between loses nothing
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => process.exit(0));

while (true) {
  try {
    await db.insert(schedules).values({ name: PURGE }).onConflictDoNothing();
    if (await claim(PURGE)) await purge();
  } catch (err) {
    console.error('[worker] Purge failed:', err);
    captureException(err);
  }
  await Bun.sleep(60_000);
}
