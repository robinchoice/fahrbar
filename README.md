# fahrbar

**Open mobility protocol for Germany.**

fahrbar is not a platform — it is a protocol. The app is the reference implementation. Anyone can fork it, self-host it, or build their own client on top of it.

Two primitives:

- **Carsharing** — list your car, rent someone else's. No middleman that can lock you out.
- **Driver service** — hire a driver to take your own car somewhere. You keep the keys.

---

## Why a protocol?

Existing services (Turo, Getaround, Uber) are closed platforms. They control the rules, take 25–40% of every transaction, and can deactivate you without appeal.

fahrbar takes a different approach:

- Open source, self-hostable backend (Supabase / PostgreSQL + PostGIS)
- Stripe Connect for fiat payments — 15% platform fee on the reference instance
- Lightning Network (LNbits) for censorship-resistant, low-fee payments — Phase 3
- Repository pattern throughout — swap out any layer without touching feature code

The reference app runs at [fahrbar.de](https://fahrbar.de). But you don't have to use it.

---

## Stack

| Layer | Technology |
|---|---|
| App | Flutter 3.29+ (iOS, Android) |
| State | Riverpod 2.x |
| Backend | Supabase (PostgreSQL + PostGIS + Realtime + Auth + Edge Functions) |
| Maps | flutter_map + OpenStreetMap |
| Payments | Stripe Connect (fiat) · LNbits (Lightning, Phase 3) |
| Smart Lock | SmartCar API (Phase 3) |

---

## Getting started

### Prerequisites

- Flutter 3.29+
- Supabase CLI
- Docker / OrbStack (for local Supabase)
- Stripe account (test keys)

### Run locally

```bash
# 1. Clone
git clone https://github.com/robinchoice/fahrbar
cd fahrbar

# 2. Start local Supabase (applies migrations + seed data automatically)
supabase start
supabase db reset

# 3. Create supabase/functions/.env with your Stripe secret key
echo "STRIPE_SECRET_KEY=sk_test_..." > supabase/functions/.env

# 4. Serve Edge Functions
supabase functions serve --env-file supabase/functions/.env &

# 5. Run on device
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<anon-key-from-supabase-start> \
  --dart-define=STRIPE_PK=pk_test_...
```

For physical device testing, replace `127.0.0.1` with your Mac's LAN IP (`ipconfig getifaddr en0`).

The local anon key is printed by `supabase start` or via `supabase status -o env`.

### Seed data

`supabase db reset` automatically runs `supabase/seed.sql`, which creates a test owner account and 5 cars in Munich:

| Email | Password |
|---|---|
| `anbieter@fahrbar.dev` | `fahrbar123` |

---

## Architecture

Feature-first, with a strict domain / data / presentation split per feature. All backend access goes through abstract repository interfaces — the Supabase implementation is one line away from being swapped out.

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

---

## Feature overview

| Feature | Status |
|---|---|
| Auth (Email · Apple · Google) | ✅ |
| Map with nearby cars (PostGIS) | ✅ |
| Car detail screen | ✅ |
| Car listing form (GPS position) | ✅ |
| Booking flow with Stripe payment | ✅ |
| Owner: accept / reject bookings | ✅ |
| Reviews (star rating + comment) | ✅ |
| In-booking chat (Supabase Realtime) | ✅ |
| Profile + booking history | ✅ |
| Driver service flow | Phase 3 |
| Push notifications | Phase 3 |
| Lightning payments (LNbits) | Phase 3 |
| SmartCar API integration | Phase 3 |

---

## Roadmap

- **Phase 1 (done):** Core loop — list, find, book, pay
- **Phase 2:** Trust & Safety — damage reports, disputes, ID verification, Stripe Connect payouts
- **Phase 3:** Driver service, smart lock integration, Lightning Network

---

## License

MIT
