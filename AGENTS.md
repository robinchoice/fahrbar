# fahrbar

## Purpose & links

- Open-source driver service: a vetted driver takes you home in your own car. Pilot in Freiburg in preparation: patients book through a practice's link `/p/<practice>`, the team sees the pickups per morning under `/team`.
- Read the local briefing `.notes/00-briefing.md` first (gitignored, not in the public repo). Its section on the business model takes precedence. Public decisions: `docs/decisions/`, the rebuild in ADR 004.
- Live: https://fahrbar.pleasance.org. Coolify project `pleasance-fahrbar`, resource `fahrbar`.
- Built on `robinchoice/starter`. The earlier Flutter and Supabase carsharing prototype is kept under the tag `carsharing-prototype`.

## Checks

`bun run check && bun run test && bun run build`, for app changes also `flutter analyze && flutter test` in `apps/mobile`.

## Deploy

- A push to `main` builds the images after green CI and deploys them through the Coolify API (README of the starter, „Deploy auf Coolify“).
- Check: `gh run watch`. The deploy job is green once `https://fahrbar.pleasance.org/api/health` reports the commit as `revision`.

## Pitfalls

- Ride details never reach the server in plain text. Everything a patient enters goes into `rideDetailsSchema` and is encrypted in the browser (`packages/shared/src/crypto.ts`); only morning, status and the hash of the patient's link are plain columns. Don't add plain columns with personal data.
- The team key exists once. Replacing it makes every booked ride unreadable, so the API refuses a second one. A lost passphrase can't be recovered.
- API and web tests put a team key with the passphrase `local test passphrase` into the database when there is none. In the local dev database that is the key to unlock `/team`.
- Only addresses in `TEAM_EMAILS` see rides. Anyone else can log in but gets no access.
- The worker (`apps/api/src/worker.ts`, service `worker` from the API image) deletes rides a week after their morning, which the booking page promises.
- Mornings are dates in Freiburg (`today()` in `packages/shared`), not timestamps.

## Abweichungen vom Standard

- No PostHog (`PUBLIC_POSTHOG_KEY` stays empty): a visit to a practice's booking link must not reach a third party.
- Screenshots show only the start page; the booking page needs a practice and the team area a login.
- No Bitcoin/Lightning: the pilot is paid in cash by decision (ADR 003), there is no payment integration.
- `apps/mobile` is only the starter scaffold until the pilot has a second driver (ADR 004).

## Konventionen

Stack und Aufbau: siehe README.md. Gestaltung: siehe DESIGN.md.

- Neue Tabelle: `packages/db/src/schema.ts` ändern, `bun run db:generate`. Die Migration läuft beim nächsten API-Start, `migrateDb` lässt mehrere Instanzen nacheinander migrieren. Jede Migration muss mit dem noch laufenden alten Code funktionieren: Spalten nullable oder mit Default hinzufügen, Umbenennen und Löschen erst im Deploy danach. Nichts von Hand in der Datenbank ändern.
- Neue Route: Datei in `apps/api/src/routes`, in `app.ts` einhängen. `requireAuth` für eingeloggte Nutzer (danach `c.get('user')`), `validJson(schema)` mit dem Schema aus `packages/shared`.
- Jeder sichtbare Text steht auf Deutsch und Englisch: für Web und API in `packages/shared/src/messages.ts`, für die App in `lib/core/messages.dart`. Fehlt eine Sprache, schlagen `bun run check` bzw. `flutter analyze` fehl. Im Web `t()` aus `$lib/i18n`, in der API `t(c)` aus `lib/i18n.ts`, in der App `ref.watch(messagesProvider)`. Eigene zod-Meldungen sind Schlüssel aus `messages.ts`. Umgeschaltet wird im `PleasanceFooter`.
- Fehler antworten immer als `{ error: string }` mit einem Text aus `t(c)`, also in der Sprache, die der Client per `Accept-Language` schickt. Das Web zeigt ihn als Toast.
- Alles, was Mails verschickt oder Geheimnisse prüft, bekommt ein `rateLimit` aus `lib/rate-limit.ts`. Die Zähler liegen in Postgres und gelten für alle API-Instanzen.
- Mails über `sendMail` aus `lib/mail.ts`.
- Zustandslos, damit eine App ohne Umbau auf einen anderen Server umzieht oder repliziert hinter einem Load Balancer läuft (`infra.md`, „Skalierung“): Platte und Prozessspeicher halten keinen Zustand, der eine Instanz überlebt oder für alle gelten muss. Sessions, Rate-Limits und Feedback liegen schon in Postgres. Uploads und Medien gehen nach S3 (Hetzner Object Storage, Bucket nach Namensregel) über `Bun.s3`, das `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_ENDPOINT` und `S3_BUCKET` selbst aus der Env liest. Kein Volume außer `pgdata`. Locks per `pg_advisory_xact_lock`. Caches im Speicher nur, wenn jede Instanz sie verlieren darf, ein geteilter Cache läuft als Valkey-Container in `docker-compose.prod.yml`.
- Hintergrundjobs und Zeitpläne laufen nie im API-Prozess, sondern als eigene Rolle: Service `worker` in `docker-compose.prod.yml` aus dem API-Image mit eigenem Einstieg `apps/api/src/worker.ts`, erst wenn ein Prototyp ihn braucht. Aufträge sind Zeilen in Postgres, der Worker holt sie mit `FOR UPDATE SKIP LOCKED`. Fällige Zeitpläne beansprucht er atomar (`update … set next_run = … where name = … and next_run <= now() returning`). So führt auch bei mehreren Workern nur einer jeden Auftrag aus, und kein Job geht bei einem Neustart verloren. Nichts in `setTimeout`, `setInterval` oder Listen im Speicher. Kurze Nacharbeit einer Anfrage wie eine Mail bleibt in der Anfrage.
- Jede Rolle hat einen Healthcheck im Image: API `/api/health` (mit Datenbank), Web `/health` (nur der Prozess), ein Worker ein `/health` auf einem eigenen Port. Uptime Kuma und ein Load Balancer prüfen `/api/health` über die öffentliche Adresse.
- Konfiguration nur über die Env: Jede neue Variable steht in `.env.example`, `.env.production.example` und `docker-compose.prod.yml`. Im Code keine Domains, IPs, Hostnamen oder Pfade des Servers. Service-Namen aus der Compose-Datei (`api`, `postgres`) sind erlaubt.
- Postgres hat im Compose eine Speichergrenze (`POSTGRES_MEMORY`, Standard `512m`). Wird sie eng, in Coolify erhöhen, nicht entfernen.
- Der Feedback-Knopf bleibt in jedem Prototyp, auch ab 1.0: Dann ist der Käfer nur im Testmodus sichtbar, „Feedback geben“ immer (README, „Feedback“). Eigene Overlays, die nicht auf den Screenshot sollen, bekommen im Web `data-feedback-ignore`. Neue API-Aufrufe laufen über `api` bzw. `apiProvider`, sonst fehlen ihre Fehler in den Meldungen. Offene Meldungen eines Repos: `gh issue list --label feedback`.
- `users.name` ist ein freier Anzeigename ohne Filter. Bekommt ein Prototyp eindeutige öffentliche Handles (z. B. `/@name`): NFKC-normalisiert und kleingeschrieben speichern und eindeutig machen, reservierte Namen sperren (`admin`, `root`, `api`, `support`, `www`, `login`, `settings`, dazu alle eigenen Routen). Einen Wortfilter für Vulgäres gibt es nur bei öffentlichen Community-Apps, dann mit `obscenity`. Eigene Wortlisten erzeugen Fehltreffer.
- Web: API-Aufrufe über `api` aus `$lib/api`, Login-Zustand aus `$lib/auth.svelte`. Seiten hinter dem Login unter `routes/(app)`.
- Externe Quellen im Browser (Skripte, Fonts, Bilder, APIs) in die CSP in `apps/web/svelte.config.js` eintragen, sonst blockt der Browser sie. Der Browser-Test in `apps/web/tests` scheitert an jedem Konsolenfehler, also auch an CSP-Verstößen. Inline-`<style>` erlaubt die CSP nur im Dev-Modus.
- Mobile (`apps/mobile`): API-Aufrufe über `apiProvider`, Login-Zustand aus `authProvider`, Seiten in `lib/features/<name>`, Routen in `lib/core/router.dart`. DTOs von Hand schreiben wie `User` in `core/auth.dart`. OpenAPI aus zod mit generiertem Client erst, wenn die API stabil ist.
- Mobile-Karte: flutter_map mit OSM. Google Maps nur, wenn Google-Places-Daten nötig sind (wie doener).
- Mobile bei Bedarf: sembast für Offline und Sync (Vorbild doener). Kein eigener Dart-Server, kein Supabase.
- Screenshots für pleasance.org: Kernscreens als öffentliche Seiten in `PAGES` in `apps/web/screenshots.ts` eintragen, die CI fotografiert sie nach jedem Deploy (README, „Screenshots“). Seiten hinter dem Login nicht, die CI hat keinen Login und die Bilder zeigen keine echten Nutzerdaten. Der Bot committet die Bilder auf `main`, vor dem Push also holen.
- Link-Vorschau: Das Layout setzt die `og:`-Tags, das Bild rendert `bun run og-image` in `apps/web` (DESIGN.md, „Vorschaubild“). Danach neu rendern und committen, wenn sich `APP_NAME`, `APP_BAND`, `tagline` oder die Kachel ändern. Die Kachel liegt als `static/favicon.svg`, dieselbe wie `img/werkzeuge/<slug>.svg` im pleasance-Repo. Öffentliche Seiten mit eigenem Inhalt, etwa geteilte Links, geben im Server-Load `meta` mit Titel, Beschreibung und optional einem absoluten Bild-URL zurück. Private Inhalte, Links mit Passwort, abgelaufene und ungültige Links bekommen die allgemeine Vorschau. Link-Crawler führen kein JavaScript aus, also wirkt `meta` nur in `+page.server.ts` bzw. `+page.ts` auf Seiten mit SSR, nicht unter `routes/(app)` (`ssr = false`). WhatsApp speichert Vorschauen lange zwischen.
- Formatierung und Lint: Biome, Regeln in `biome.json`. `bun run format` behebt das meiste selbst.
- Apple-Zugangsdaten der Prototype Factory stehen zentral in `~/.secrets`: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (base64), dazu das CI-Signing-Zertifikat `APPLE_CI_DEV_CERTIFICATE_BASE64` (base64-PKCS12) und `APPLE_CI_DEV_CERTIFICATE_PASSWORD`. Ablage und Kopien: `~/dev/kontor/infra.md`, Abschnitt „Zugangsdaten: wo liegt was“. Im selben Aufruf mit `set -a; . ~/.secrets; set +a` laden; Werte nie ausgeben oder ins Repo schreiben. Nach Freigabe richtet `~/dev/kontor/apple-ci-secrets.sh robinchoice/<repo>` die GitHub-CI ein: ASC-IDs als Variablen, `ASC_KEY_P8`, `IOS_DEV_CERTIFICATE` und `IOS_DEV_CERTIFICATE_PASSWORD` als Secrets.
