import type { FeedbackContext, RideStatus } from '@app/shared';
import {
  customType,
  date,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

const bytea = customType<{ data: Buffer }>({ dataType: () => 'bytea' });

export const users = pgTable('users', {
  id: uuid('id').defaultRandom().primaryKey(),
  // Stored lowercase, see the email schema in @app/shared
  email: varchar('email', { length: 255 }).notNull().unique(),
  name: varchar('name', { length: 255 }).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const magicLinks = pgTable('magic_links', {
  id: uuid('id').defaultRandom().primaryKey(),
  email: varchar('email', { length: 255 }).notNull(),
  tokenHash: varchar('token_hash', { length: 64 }).notNull().unique(),
  expiresAt: timestamp('expires_at').notNull(),
  usedAt: timestamp('used_at'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

// Mobile apps log in with a code from the mail, a link can't open the app
export const loginCodes = pgTable('login_codes', {
  id: uuid('id').defaultRandom().primaryKey(),
  email: varchar('email', { length: 255 }).notNull(),
  codeHash: varchar('code_hash', { length: 64 }).notNull(),
  attempts: integer('attempts').default(0).notNull(),
  expiresAt: timestamp('expires_at').notNull(),
  usedAt: timestamp('used_at'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const sessions = pgTable('sessions', {
  id: uuid('id').defaultRandom().primaryKey(),
  userId: uuid('user_id')
    .references(() => users.id, { onDelete: 'cascade' })
    .notNull(),
  tokenHash: varchar('token_hash', { length: 64 }).notNull().unique(),
  expiresAt: timestamp('expires_at').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

// Counters of lib/rate-limit.ts in the API
export const rateLimits = pgTable('rate_limits', {
  key: varchar('key', { length: 300 }).primaryKey(),
  count: integer('count').notNull(),
  resetAt: timestamp('reset_at').notNull(),
});

// Bug reports and ideas from the feedback button, also mailed and filed as
// GitHub issues. The random id is the key of the screenshot URL.
export const feedback = pgTable('feedback', {
  id: uuid('id').defaultRandom().primaryKey(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'set null' }),
  kind: varchar('kind', { length: 10 }).notNull(),
  message: text('message').notNull(),
  screenshot: bytea('screenshot'),
  context: jsonb('context').$type<FeedbackContext & { api: string }>().notNull(),
  issueUrl: varchar('issue_url', { length: 300 }),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

// Partner practices. Each hands out its own booking link /p/<slug>.
export const practices = pgTable('practices', {
  id: uuid('id').defaultRandom().primaryKey(),
  slug: varchar('slug', { length: 40 }).notNull().unique(),
  name: varchar('name', { length: 120 }).notNull(),
  address: varchar('address', { length: 200 }).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

// The fixed fahrbar mornings of a practice. Times are local to Freiburg.
export const mornings = pgTable(
  'mornings',
  {
    id: uuid('id').defaultRandom().primaryKey(),
    practiceId: uuid('practice_id')
      .references(() => practices.id, { onDelete: 'cascade' })
      .notNull(),
    date: date('date').notNull(),
    start: varchar('start', { length: 5 }).notNull(),
    end: varchar('end', { length: 5 }).notNull(),
    capacity: integer('capacity').notNull(),
    createdAt: timestamp('created_at').defaultNow().notNull(),
  },
  (t) => [unique().on(t.practiceId, t.date)],
);

// One booked ride. payload is encrypted to the team key in the browser, the
// server never sees the details. The worker deletes rides a week after their morning.
export const rides = pgTable(
  'rides',
  {
    id: uuid('id').defaultRandom().primaryKey(),
    morningId: uuid('morning_id')
      .references(() => mornings.id, { onDelete: 'cascade' })
      .notNull(),
    payload: text('payload').notNull(),
    status: varchar('status', { length: 20 }).$type<RideStatus>().default('new').notNull(),
    // Lets the patient look at and cancel the booking without an account
    manageTokenHash: varchar('manage_token_hash', { length: 64 }).notNull().unique(),
    createdAt: timestamp('created_at').defaultNow().notNull(),
  },
  (t) => [index().on(t.morningId)],
);

// The single team key pair, the private half encrypted with the team passphrase
export const teamKey = pgTable('team_key', {
  id: integer('id').default(1).primaryKey(),
  publicKey: text('public_key').notNull(),
  encryptedPrivateKey: text('encrypted_private_key').notNull(),
  salt: text('salt').notNull(),
  iv: text('iv').notNull(),
  iterations: integer('iterations').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

// Recurring jobs of the worker. A worker claims a due job by moving next_run in
// the same statement, so with several workers only one runs it.
export const schedules = pgTable('schedules', {
  name: varchar('name', { length: 50 }).primaryKey(),
  nextRun: timestamp('next_run').defaultNow().notNull(),
});
