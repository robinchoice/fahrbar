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
| **Carsharing** — rent out your car or rent someone else's | Planned after the pilot, with group insurance. The earlier prototype is kept under the tag `carsharing-prototype` |

---

## Stack

| Layer | Technology |
|---|---|
| Web | SvelteKit (`apps/web`): booking page for patients, team area |
| API | Hono on Bun (`apps/api`), Drizzle and Postgres (`packages/db`), a worker that deletes rides a week after their morning |
| Driver app | Flutter (`apps/mobile`), only the scaffold during the pilot |
| Encryption | Web Crypto in the browser: P-256, HKDF and AES-GCM (`packages/shared/src/crypto.ts`) |
| Payments | Cash during the pilot, counted out in advance, receipt without a name. No in-app payment |

Everything is open source and self-hosted in Germany, without Supabase, Google or other hosted services. The stack follows the [starter](https://github.com/robinchoice/starter) of Pleasance. The carsharing prototype on Flutter and Supabase is kept under the tag [`carsharing-prototype`](https://github.com/robinchoice/fahrbar/tree/carsharing-prototype), see [ADR 004](docs/decisions/004-neubau-auf-starter.md).

---

## How it works

1. A partner practice hands out its booking link, `/p/<practice>`.
2. The patient picks one of the practice's fahrbar mornings and the time of the appointment, then enters first name, destination, car and phone. No account, no surname, no procedure or diagnosis.
3. The browser encrypts these details to the team's public key. The server stores only the ciphertext plus morning and status, and deletes the ride a week after its morning.
4. The team logs in by magic link, unlocks the team key with its passphrase in the browser and sees the pickups of each morning. The patient's link shows the status and lets them cancel.

---

## Getting started

Requires Bun, Docker, and Flutter for the app.

```sh
cp .env.example .env    # put your address into TEAM_EMAILS
docker compose up -d
bun install
bunx playwright install chromium   # once, for the browser tests
bun run dev
```

Web runs on http://localhost:5173, the API on port 3000. Without `SMTP_HOST` the login links appear in the API log. Log in at `/login`, set the team passphrase at `/team`, add a practice and a morning, then book through the practice link.

Checks: `bun run check && bun run test && bun run build`, for the app `flutter analyze && flutter test` in `apps/mobile`.

Decisions are recorded in [`docs/decisions/`](docs/decisions/).

---

## Roadmap

**Pilot**

1. Talk to practices in Freiburg: would they accept a fahrbar driver as the pick-up after sedation, and would they put patients without an escort on two fixed fahrbar mornings a week?
2. Free test rides on those mornings, driven by ourselves.
3. Paid rides once demand is confirmed: legal and insurance setup, fixed price, paid in cash. A minijob driver joins once a morning has had at least three pick-ups four weeks in a row.

**Later:** the list of pickups in the driver app once there are drivers to assign, carsharing with group insurance, the open network, more cities and data export.

---

## License

[MIT](LICENSE)
