# fahrbar

**Open-source driver service: get driven home in your own car.**

fahrbar is an open-source platform for driver services. A vetted driver comes to you and drives *your own car*, so you keep your keys and your car comes home with you.

We're starting small: a pilot in Freiburg im Breisgau for patients who aren't allowed to drive after an outpatient procedure (sedation, e.g. a colonoscopy, or pupil-dilating eye drops). Rides are booked in advance and driven by a small, personally vetted team.

Why fahrbar changed course: [ADR 002](docs/decisions/002-fahrer-service-pilot.md).

---

## Principles

- **Open** — The code is open source and can be forked and self-hosted. Users will be able to export their data. A shared protocol between independent operators stays a long-term vision until a second operator or client actually wants to connect.
- **Fair** — Nobody gets locked out without a reason and a way to appeal. Bans follow published rules, come with a justification and can be appealed.
- **Transparent** — A fixed price per ride with an open breakdown (driver wage, insurance, fahrbar) instead of a hidden commission.

---

## Services

| Service | Status |
|---|---|
| **Driver service** — a vetted driver takes you home in your own car | Pilot in preparation (Freiburg) |
| **Carsharing** — rent out your car or rent someone else's | Paused, prototype code stays in the repo |

---

## Stack

| Layer | Technology |
|---|---|
| App | Flutter 3.41.6+ (iOS/Android app for drivers, web version for booking) |
| State | Riverpod 2.x |
| Backend | Supabase (PostgreSQL + PostGIS + Realtime + Auth + Edge Functions), self-hostable |
| Maps | flutter_map + OpenStreetMap |
| Payments | Invoice after the ride during the pilot · Stripe integration paused with carsharing |

---

## Getting started

### Prerequisites

- Flutter 3.41.6+
- Supabase CLI
- Docker / OrbStack (for local Supabase)

### Run locally

```bash
# 1. Clone
git clone https://github.com/robinchoice/fahrbar
cd fahrbar

# 2. Start local Supabase (applies migrations + seed data automatically)
supabase start
supabase db reset

# 3. Run the app
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<anon-key-from-supabase-start>
```

The local anon key is printed by `supabase start` or via `supabase status -o env`. For testing on a physical device, replace `127.0.0.1` with your machine's LAN IP.

### Apple and Google sign-in

Both providers are enabled in `supabase/config.toml` and read their credentials from `supabase/.env` (gitignored):

```bash
SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID=...
SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=...
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=...
SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=...
```

The iOS and Android apps come back through the deep link `de.fahrbar://login-callback`, the web build through `site_url`. Locally that is `http://127.0.0.1:3000`, so start the web app with `flutter run -d chrome --web-hostname 127.0.0.1 --web-port 3000`.

### Carsharing payments (paused)

The carsharing prototype pays via Stripe. To try it with test keys:

```bash
echo "STRIPE_SECRET_KEY=sk_test_..." > supabase/functions/.env
supabase functions serve --env-file supabase/functions/.env &
```

Then add `--dart-define=STRIPE_PK=pk_test_...` to `flutter run`. Stripe is not available in the web build.

### Seed data

`supabase db reset` automatically runs `supabase/seed.sql`, which creates a test owner account and 5 cars around Freiburg:

| Email | Password |
|---|---|
| `anbieter@fahrbar.dev` | `fahrbar123` |

---

## What's in the code today

- Email sign-in, plus Apple and Google sign-in once their credentials are set (see above).
- Carsharing prototype: map with nearby cars (PostGIS), car detail, listing form, booking with Stripe payment, owner confirm/reject.
- In-booking chat with live updates via Supabase Realtime.
- Reviews: the rate button only shows for `completed` bookings, and nothing sets that status yet. Reviews aren't displayed anywhere.
- Not production-ready: access rules (RLS) and payments need hardening before any real use.

---

## Architecture

Feature-first, with a domain / data / presentation split per feature. Feature code talks to abstract repository interfaces; the Supabase implementations live in `data/`.

```
lib/
  features/
    auth/        domain · data · presentation
    cars/        domain · data · presentation
    booking/     domain · data · presentation
    messages/    domain · data · presentation
    reviews/     domain · data · presentation
    profile/     presentation
    home/        presentation
  core/
    theme · router · widgets
  providers/
    supabase_provider · auth_provider

supabase/
  migrations/   schema + PostGIS RPC
  functions/    create-payment-intent (Stripe Edge Function)
  seed.sql      test data
```

Decisions are recorded in [`docs/decisions/`](docs/decisions/).

---

## Roadmap

**Pilot**

1. Talk to practices in Freiburg: would they accept a fahrbar driver as the pick-up after sedation?
2. Free test rides with a small, vetted driver team.
3. Paid rides once demand is confirmed: legal and insurance setup, fixed price, invoice after the ride.

**App (in parallel)**

- Web booking for patients
- Driver app for iOS and Android via TestFlight
- Admin view for assigning rides

**Later:** more drivers and cities, data export, and the protocol vision.

---

## License

[MIT](LICENSE)
