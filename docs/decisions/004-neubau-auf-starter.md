# ADR 004 — Neubau auf dem Pleasance-Starter

**Status:** Accepted  
**Datum:** 2026-10-09  
**Kontext:** fahrbar — Umbau vor dem Pilot

## Kontext

fahrbar lief als Flutter-App mit Supabase als Backend (ADR 001). Gebaut war der Carsharing-Prototyp. Für den Pilot braucht es nach ADR 003 nur ein Buchungsformular im Web, dessen Fahrtdaten nur das Team lesen kann, und eine Liste pro Vormittag. Supabase bindet Auth, Realtime und Datenzugriff an einen Anbieter, und eine Flutter-Web-App ist für ein Formular, das Patienten einmal öffnen, schwer und langsam.

## Entscheidung

fahrbar wird im selben Repo auf dem Starter von Pleasance neu gebaut: SvelteKit fürs Web, eine Hono-API auf Bun, Drizzle und Postgres, die Flutter-App als Fahrer-App in `apps/mobile` gegen dieselbe API. Supabase, Stripe und alle anderen gehosteten Dienste fallen weg.

| # | Thema | Entscheidung |
|---|---|---|
| 1 | Carsharing-Code | Verlässt `main`. Der Stand liegt unter dem Tag `carsharing-prototype` |
| 2 | Buchung | Ohne Konto über einen Link pro Praxis, in zwei Schritten: Vormittag und Terminzeit, dann Vorname, Ziel, Auto und Telefon |
| 3 | Verschlüsselung | Der Browser verschlüsselt die Fahrtdaten an den öffentlichen Team-Schlüssel (P-256, HKDF, AES-GCM). Der private Schlüssel liegt mit der Team-Passphrase verschlüsselt auf dem Server und wird nur im Browser entsperrt |
| 4 | Identität bei der Abholung | Vorname und Kennzeichen, kein Nachname |
| 5 | Löschen | Ein Worker löscht Fahrten eine Woche nach ihrem Vormittag. Absagen löscht sofort |
| 6 | Team | Login per Magic Link, Zugang nur für die Adressen in `TEAM_EMAILS` |
| 7 | Fahrer-App | Im Pilot nur das Gerüst aus dem Starter. Die Liste der Abholungen kommt mit dem ersten Minijobber |
| 8 | Analyse | Kein PostHog: Der Aufruf eines Buchungslinks einer Praxis geht an keinen Dritten |

## Begründung

- **Unabhängig bleiben.** Der Starter ist FOSS und läuft auf dem eigenen Server in Deutschland. Ein Wechsel des Hosts heißt Container umziehen, nicht eine Plattform ablösen.
- **Das Formular muss leicht sein.** Patienten öffnen den Link einmal auf dem Handy. Eine SvelteKit-Seite lädt schnell und ohne Installation.
- **Schlüssel statt Konten.** ADR 003 verlangt Fahrtdaten, die nur das Team lesen kann. Web Crypto reicht dafür ohne zusätzliche Bibliothek, und das Muster passt später ins offene Netz.
- **Der Vorname reicht.** Der Empfang der Praxis muss wissen, wen der Fahrer abholt. Ein Vorname mit Kennzeichen genügt, ein Nachname würde aus den Fahrtdaten eine Patientenliste machen.

## Konsequenzen

- Geht die Team-Passphrase verloren, sind alle gebuchten Fahrten unlesbar. Sie gehört in den Passwortmanager.
- Wer die Seite neu lädt, entsperrt den Schlüssel erneut.
- ADR 001 ist für die Patienten-Buchung überholt, für die Fahrer-App gilt Flutter weiter.
