# fahrbar

**Open-source driver service: get driven home in your own car.**

fahrbar is an open-source platform for driver services. A vetted driver comes to you and drives *your own car*, so you keep your keys and your car comes home with you.

We're starting small: a pilot in Freiburg im Breisgau for patients who aren't allowed to drive after an outpatient procedure (sedation, e.g. a colonoscopy, or pupil-dilating eye drops). Rides are booked in advance and driven by a small, personally vetted team.

Why fahrbar changed course: [ADR 002](docs/decisions/002-fahrer-service-pilot.md). How it makes money and where it's headed: [ADR 003](docs/decisions/003-offenes-netz-bezahltes-team.md).

---

## Principles

- **Open** — The code is open source and can be forked and self-hosted. Users will be able to export their data. Long term, fahrbar is meant to grow into an open network modeled on Vexl: you find drivers and cars through people you know, and matching is free.
- **Private** — Ride details are end-to-end encrypted, so only the team driving you can read them. Keys instead of accounts. You pay in cash and get a receipt without your name.
- **Fair** — Nobody gets locked out without a reason and a way to appeal. Bans follow published rules, come with a justification and can be appealed.
- **Transparent** — A fixed price per ride with an open breakdown (driver wage, insurance, fahrbar) instead of a hidden commission.

---

## Services

| Service | Status |
|---|---|
| **Driver service** — a vetted driver takes you home in your own car | Pilot in preparation (Freiburg) |
| **Carsharing** — rent out your car or rent someone else's | Planned after the pilot, with group insurance. Prototype code stays in the repo |

---

## Stack

| Layer | Technology |
|---|---|
| App | Flutter 3.41.6+ (web booking in the pilot, iOS/Android app for drivers later) |
| State | Riverpod 2.x |
| Backend | Supabase (PostgreSQL + PostGIS + Realtime + Auth), self-hostable |
| Maps | flutter_map + OpenStreetMap |
| Payments | Cash during the pilot, counted out in advance, receipt without a name. No in-app payment |

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

The map loads the public OpenStreetMap tiles, which are only meant for light use such as development. Release builds need a tile provider that allows app use: `--dart-define=MAP_TILE_URL=https://…/{z}/{x}/{y}.png`.

### Apple and Google sign-in

Both providers are enabled in `supabase/config.toml` and read their credentials from `supabase/.env` (gitignored):

```bash
SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID=...
SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=...
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=...
SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=...
```

The iOS and Android apps come back through the deep link `de.fahrbar://login-callback`, the web build through `site_url`. Locally that is `http://127.0.0.1:3000`, so start the web app with `flutter run -d chrome --web-hostname 127.0.0.1 --web-port 3000`.

### Seed data

`supabase db reset` automatically runs `supabase/seed.sql`, which creates a test owner account and 5 cars around Freiburg:

| Email | Password |
|---|---|
| `anbieter@fahrbar.dev` | `fahrbar123` |

---

## What's in the code today

- Email sign-in, plus Apple and Google sign-in once their credentials are set (see above).
- Carsharing prototype: map with nearby cars (PostGIS), car detail, listing form, booking requests without payment that the owner confirms or rejects.
- In-booking chat with live updates via Supabase Realtime.
- Reviews: once the owner confirms the return, the renter can rate the rental. Reviews and ratings show up on the car.

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
    theme · router · brand (Pleasance band, tile, footer)
  config.dart    section of the family colour band
  providers/
    supabase_provider · auth_provider

supabase/
  migrations/   schema + PostGIS RPC
  seed.sql      test data
```

Decisions are recorded in [`docs/decisions/`](docs/decisions/).

---

## Roadmap

**Pilot**

1. Talk to practices in Freiburg: would they accept a fahrbar driver as the pick-up after sedation, and would they put patients without an escort on two fixed fahrbar mornings a week?
2. Free test rides on those mornings, driven by ourselves.
3. Paid rides once demand is confirmed: legal and insurance setup, fixed price, paid in cash. A minijob driver joins once a morning has had at least three pick-ups four weeks in a row.

**App (in parallel)**

- Web booking form for patients, with ride details end-to-end encrypted so only the team can read them

**Later:** a driver app once there are drivers to assign, carsharing with group insurance, the open network, more cities and data export.

---

## License

[MIT](LICENSE)
