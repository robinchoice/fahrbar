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

Checks: `bun run check && bun run test`, for the app `flutter analyze && flutter test` in `apps/mobile`.
The browser tests (Playwright) build the web app and start API and web build themselves on their own ports 31100 and 31101, never against running dev servers, so the CSP applies as in production. Test ports stay below Linux’s ephemeral range (32768–60999). Two worktrees testing at the same time pick other ports below 32768 via `TEST_API_PORT` and `TEST_WEB_PORT`, e.g. 31102 and 31103.

`bun run test` gives the API and browser suites separate empty databases on the server from `DATABASE_URL`. The user needs `CREATEDB` (local Compose and CI users already have it). After success, failure or SIGINT/SIGTERM only that temporary database is dropped; the development database stays untouched. Running the package scripts in `apps/api` or `apps/web` also isolates the database; direct `bun test` or `playwright test` bypasses it.

### Login in the Savor preview

Agents show changes behind the login in the Savor preview. `login-link <slug>` from the kontor runs `bun apps/api/src/login-link.ts <email>` in the API container, which prints a one-time login link, valid for 15 minutes like a mailed one. Sessions in use renew to 365 days on each visit, at most once a day, so the preview stays logged in. Only addresses in `TEAM_EMAILS` see rides, and reading them still needs the team passphrase. The agents' test account admin@pleasance.org has no admin rights in the app (see "Opening sign-up").

### Login and passkeys

The login mail includes a link and a six-digit code, also in the subject. Both are valid for 15 minutes. The web redeems the code into an httpOnly cookie; native clients receive a bearer token. Sessions last 365 days and renew during use at most once a day, equally for web and app.

Logged-in users add and remove web passkeys under `/settings`. The login page offers saved passkeys as email autofill and through a button, using SimpleWebAuthn. Challenges are single-use rows in Postgres, valid for five minutes. Passkeys belong to the hostname in `APP_URL`: after moving domains, users log in by mail and add a new passkey. Locally use `localhost`; a plain HTTP LAN address cannot use WebAuthn. Removed passkeys are rejected and the browser is asked to forget them.

Native passkeys and domain association endpoints are deferred until the app signing certificates and Associated Domains are configured (backlog “Braucht Robin”). The pilot app remains a scaffold.

### Opening sign-up

fahrbar is reachable from outside but closed until Robin explicitly gives the go to take in external users. Until then magic link and app code only create new accounts for the addresses in `SIGNUP_ALLOWLIST` and `TEAM_EMAILS` (comma-separated). Existing accounts always log in. Strangers get "Sign-up is still closed" from `/auth/magic-link` and `/auth/code`, and no mail goes out. Link and code redemption check the current allowlist again before creating a session. Passkey registration requires a session and does not open sign-up. The booking page `/p/<practice>` needs no login and stays open.

- Adding a tester: an admin clicks "Tester einladen" at the top of the app (`/invite`) and enters the address. That creates the account and sends a login link, without Coolify or a redeploy. Admins are the addresses in `ADMIN_EMAILS` (comma-separated, by default robin@pleasance.org, the human admin), the API checks it. Inviting opens nothing, `SIGNUP_OPEN` stays as it is.
- admin@pleasance.org, the agents' admin, never goes into `ADMIN_EMAILS`: agents log in with it in the preview and must neither create accounts past the closed sign-up nor mail third parties.
- Opening, only after Robin's go: set `SIGNUP_OPEN=true` in Coolify and redeploy. Check: request a login link for a new address.
- `login-link` creates accounts itself, the preview's test account needs no entry. The script takes any address, the limit sits on the server: agents don't get into the container, only through the root-owned `login-link` from the kontor, which always passes admin@pleasance.org. Whoever gets into the container has the database anyway.

### For agents

Other people's agents read the public content without HTML, following [llms.txt](https://llmstxt.org). The source is `publicPages` in `apps/api/src/lib/public-pages.ts`, the routes are in `apps/api/src/routes/agents.ts`. The web server forwards these paths to the API.

- `/llms.txt`: entry point with name, tagline and every public page as a link to its Markdown.
- `/llms-full.txt`: all pages in one file.
- `<page>.md`: every page as Markdown, the start page as `/index.md`. An agent asking for a page with `Accept: text/markdown` gets the Markdown under the same URL, everyone else the HTML.
- Language: `?lang=de|en`, else `Accept-Language`, else German. Links keep a `?lang=`.
- Public content only: the start page. Practices' booking links and patients' ride links are handed out personally and stay out.
- Try it: `curl localhost:5173/llms.txt` while `bun run dev` runs.

### Secret scan

The repo is public: code, history and CI logs. `.github/workflows/secrets.yml` runs on every push to every branch and on pull requests from forks, without `paths-ignore`, and scans the new commits with gitleaks (Docker image pinned by digest). A finding fails the run, `--redact` keeps the value out of the log.

- Rules: the gitleaks defaults plus `.gitleaks.toml`, which only skips `generic-api-key` in `bun.lock` and `pubspec.lock`, where hashes trip it. Real token formats (`ghp_…`, `sk_live_…`) are still caught there.
- False positive: add the `Fingerprint` from the log as a line to `.gitleaksignore`.
- Real finding: the scan runs after the push, so the secret is already public. Rotate it right away, removing it from the code or the history isn't enough.

### App releases

The mobile workflow checks `flutter analyze`, `flutter test` and `node --test tool/testflight.test.mjs` in `apps/mobile`. Main and manual iOS builds distribute internally; only pushed `v*` release tags distribute to external testers and submit for beta review. Agents create release tags only when Robin explicitly asks, because external distribution notifies testers.

Before enabling iOS builds, configure GitHub variables `API_URL`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_BUNDLE_ID` (matching the iOS bundle ID) and `TESTFLIGHT_INTERNAL_GROUP` (exact group name). Release tags also require `TESTFLIGHT_EXTERNAL_GROUP`. Existing signing secrets remain unchanged.

Create the internal group in App Store Connect with “Enable automatic distribution”; Apple’s API cannot enable it for an existing group. External releases need an external group with testers, completed beta metadata, review contact, any required test login and export compliance. The `testflight` job waits up to an hour for processing and verified internal visibility; uploading alone does not count as success. Apple controls external approval.

After a partial distribution failure, retry the existing build with the same `ASC_*` and `TESTFLIGHT_*` configuration and matching checkout: `node tool/testflight.mjs <build number>` for internal distribution, or `node tool/testflight.mjs --release <build number>` for both groups. The script detects existing assignments and reviews; do not upload the same build number again.

`.github/workflows/mobile.yml` builds release versions of the app with `--obfuscate --split-debug-info`, so stack traces from the app (in GlitchTip too) only show obfuscated names. The symbols stay with the CI run for 90 days as the artifact `symbols-android` or `symbols-ios`, and the app's build number is that run's number (`gh run list -w mobile.yml --json number,databaseId` gives the run ID). To make a trace readable:

```sh
gh run download <run-id> -n symbols-android -D /tmp/symbols
flutter symbolize -i trace.txt -d /tmp/symbols/app.android-arm64.symbols   # iOS: app.ios-arm64.symbols
```

`trace.txt` is the raw stack trace with `build_id` and `abs …/virt …` lines (e.g. from `adb logcat`). Builds older than 90 days can't be symbolized any more. Obfuscation is no protection: everything in the web bundle and the app can be read, so no secrets in the client.

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
