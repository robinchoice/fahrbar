import { z } from 'zod';
import type { Band } from './band';

export * from './band';
export * from './crypto';
export * from './messages';

// The one place to rename a new project. API mails and web titles read it.
export const APP_NAME = 'fahrbar';

// Section of the family colour band for this product, see DESIGN.md
export const APP_BAND: Band = { from: 1, to: 1.35 };

// True once the project is live as 1.0 (README, "Live als 1.0"). From then on
// the bug button waits for the test mode switch, see testMode in the web's feedback.svelte.ts.
export const LIVE = false;

export type User = {
  id: string;
  email: string;
  name: string;
};

// Custom error messages are keys of messages.ts, the API translates them.
const email = z.string().trim().toLowerCase().pipe(z.email('invalidEmail'));

export const magicLinkSchema = z.object({
  email,
  // Page to return to after login, see safeNextPath
  next: z.string().max(2000).optional(),
});

export const verifySchema = z.object({
  token: z.string().min(1).max(200),
});

export const loginCodeSchema = z.object({ email });

export const verifyCodeSchema = z.object({
  email,
  code: z
    .string()
    .trim()
    .regex(/^\d{6}$/, 'codeDigits'),
});

export const updateMeSchema = z.object({
  name: z.string().trim().min(1).max(255),
});

// What web and app send along with feedback. The API adds its own version.
// Today as YYYY-MM-DD in Freiburg, where all mornings take place
export const today = (now = new Date()) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Berlin' }).format(now);

// Fixed price per ride in euros, paid in cash on arrival
export const PRICE = 49;

const time = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'invalidInput');
const toMinutes = (value: string) => Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5));
const fromMinutes = (minutes: number) =>
  `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;

// Patients are discharged about 90 minutes after their appointment
const PICKUP_DELAY = 90;

export const pickupTime = (appointment: string) => fromMinutes(toMinutes(appointment) + PICKUP_DELAY);

// Appointments whose pickup falls into the morning, every half hour
export function appointmentTimes(start: string, end: string) {
  const times: string[] = [];
  for (let m = toMinutes(start) - PICKUP_DELAY + 30; m <= toMinutes(end) - PICKUP_DELAY; m += 30) {
    times.push(fromMinutes(m));
  }
  return times;
}

// What the patient enters. It never reaches the server in plain text: the browser
// encrypts it to the team key, see crypto.ts.
export const rideDetailsSchema = z.object({
  firstName: z.string().trim().min(1, 'firstNameMissing').max(60),
  appointment: time,
  street: z.string().trim().min(3, 'streetMissing').max(120),
  city: z.string().trim().min(3, 'cityMissing').max(80),
  plate: z.string().trim().min(2, 'plateMissing').max(15),
  car: z.string().trim().max(60),
  phone: z
    .string()
    .trim()
    .regex(/^\+?[\d ()/-]{6,30}$/, 'phoneInvalid'),
});

export type RideDetails = z.infer<typeof rideDetailsSchema>;

export const bookRideSchema = z.object({
  morningId: z.uuid(),
  payload: z.string().startsWith('v1.').max(4000),
});

export const RIDE_STATUSES = ['new', 'confirmed', 'picked_up', 'arrived'] as const;
export type RideStatus = (typeof RIDE_STATUSES)[number];

export const rideStatusSchema = z.object({ status: z.enum(RIDE_STATUSES) });

export type Practice = { id: string; slug: string; name: string; address: string };

export type Morning = {
  id: string;
  practiceId: string;
  // Local date in Freiburg, YYYY-MM-DD
  date: string;
  start: string;
  end: string;
  capacity: number;
  booked: number;
};

export type Ride = { id: string; status: RideStatus; payload: string; createdAt: string };

export const practiceSchema = z.object({
  slug: z
    .string()
    .trim()
    .regex(/^[a-z0-9-]{2,40}$/, 'slugInvalid'),
  name: z.string().trim().min(2).max(120),
  address: z.string().trim().min(5).max(200),
});

export const morningSchema = z
  .object({
    practiceId: z.uuid(),
    date: z.iso.date(),
    start: time,
    end: time,
    capacity: z.number().int().min(1).max(12),
  })
  .refine((m) => toMinutes(m.end) - toMinutes(m.start) >= 60, 'invalidInput');

export const teamKeySchema = z.object({
  publicKey: z.base64().max(200),
  encryptedPrivateKey: z.base64().max(1000),
  salt: z.base64().max(100),
  iv: z.base64().max(100),
  iterations: z.number().int().min(100_000).max(10_000_000),
});

export const feedbackContextSchema = z.object({
  platform: z.enum(['web', 'ios', 'android']),
  page: z.string().max(500),
  // App build; the web runs the same commit as the API
  version: z.string().max(100).optional(),
  device: z.string().max(300),
  viewport: z.string().max(50),
  locale: z.string().max(10),
  // Failed API calls as "METHOD /path → status", newest first
  errors: z.array(z.string().max(300)).max(5),
});

export type FeedbackContext = z.infer<typeof feedbackContextSchema>;

export const feedbackSchema = z.object({
  kind: z.enum(['bug', 'idea']),
  message: z.string().trim().min(5, 'feedbackTooShort').max(5000),
  // PNG or JPEG, up to about 5 MB
  screenshot: z.base64().max(7_000_000).optional(),
  context: feedbackContextSchema,
});

// A path on this site to return to after login. Anything that would resolve to
// another origin (//host, /\host, or tabs and newlines that browsers strip) is
// dropped, so a crafted link can't redirect elsewhere.
export function safeNextPath(value: string | null | undefined): string | null {
  if (!value?.startsWith('/')) return null;
  try {
    const url = new URL(value, 'http://localhost');
    return url.origin === 'http://localhost' ? url.pathname + url.search + url.hash : null;
  } catch {
    return null;
  }
}
