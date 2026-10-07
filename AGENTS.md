# fahrbar

## Purpose & links

- Open-source driver service: a vetted driver takes you home in your own car. Pilot in Freiburg in preparation. Flutter app with Supabase as the backend.
- Read the local briefing `.notes/00-briefing.md` first (gitignored, not in the public repo). Its section on the business model takes precedence. Public decisions: `docs/decisions/`.
- Nothing in this repo deploys it yet: no CI, no hosting config.

## Checks

`flutter pub get && flutter analyze && flutter test`

## Deploy

None yet. Pushing to `main` only publishes the code.

## Pitfalls

- Build the web app with `--no-web-resources-cdn`, otherwise Flutter loads CanvasKit and fonts from Google.
- Carsharing code from the earlier prototype stays in the repo for after the pilot. Don't remove it.
