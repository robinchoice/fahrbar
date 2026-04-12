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
| App | Flutter 3.29+ (iOS, Android, PWA) |
| State | Riverpod 2.x |
| Backend | Supabase (PostgreSQL + PostGIS + Realtime + Auth + Storage) |
| Maps | flutter_map + OpenStreetMap tiles |
| Payments | Stripe Connect (fiat) · LNbits (Lightning, Phase 3) |
| Smart Lock | SmartCar API (Phase 3) |

---

## Getting started

### Prerequisites

- Flutter 3.29+
- Supabase CLI
- Docker (for local Supabase)

### Run locally

```bash
# 1. Clone
git clone https://github.com/robinchoice/fahrbar
cd fahrbar

# 2. Start local Supabase
supabase start

# 3. Apply migrations
supabase db push

# 4. Run the app (web)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://localhost:54321 \
  --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key>
```

The local anon key is printed by `supabase start`.

---

## Architecture

Feature-first, with a strict domain / data / presentation split per feature.
All backend access goes through abstract repository interfaces — the Supabase
implementation is one line away from being swapped out.

```
lib/
  features/
    auth/       domain · data · presentation
    cars/       domain · data · presentation
    booking/    domain · data · presentation
    payments/   domain · data · presentation
    profile/    domain · data · presentation
  core/
    theme · router · constants · widgets · utils
  providers/
    supabase_provider · auth_provider
```

See `.notes/00-briefing.md` (gitignored) for full implementation notes.

---

## Roadmap

- [x] Project scaffold, theme, routing
- [x] Auth (Email · Apple · Google)
- [x] Database schema + PostGIS migrations
- [x] Map with nearby cars
- [ ] Car detail screen
- [ ] Booking flow (carsharing)
- [ ] Stripe Connect integration
- [ ] Push notifications
- [ ] Trust & Safety (damage reports, chat, reviews)
- [ ] Driver service flow
- [ ] Lightning payments (LNbits)
- [ ] SmartCar API integration

---

## License

MIT
