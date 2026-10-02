# ADR 002 — Neuausrichtung: Fahrer-Service-Pilot statt Mobilitätsprotokoll

**Status:** Accepted, teilweise abgelöst durch [ADR 003](003-offenes-netz-bezahltes-team.md)  
**Datum:** 2026-10-01  
**Kontext:** fahrbar — Philosophie-Workshop

## Kontext

Das README positionierte fahrbar als „offenes Mobilitätsprotokoll für Deutschland“ mit zwei Säulen (Carsharing und Fahrer-Service), 15 % Plattformgebühr über Stripe Connect und Lightning-Zahlungen in Phase 3. Gebaut war eine Carsharing-App mit Live-Karte, Stripe-Zahlung, Chat und Bewertungen. Nutzer, weitere Betreiber oder eine Protokoll-Spezifikation gab es nicht.

Ein Workshop hat die Annahmen einzeln geprüft. Dieses ADR hält das Ergebnis fest.

## Entscheidung

fahrbar ist eine **Open-Source-Plattform für Fahrdienste im eigenen Auto**. Der Start ist ein Side-Projekt mit kleinem Pilot in Freiburg: Geprüfte Fahrer bringen Patienten nach ambulanten Eingriffen in deren eigenem Auto nach Hause.

### Prinzipien

- **Offen:** Der Code ist offen und forkbar, Nutzer können ihre Daten exportieren. Ein Protokoll bleibt Vision, bis ein zweiter Betreiber oder Client andocken will.
- **Fair:** Niemand wird ohne Grund und ohne Einspruch ausgesperrt. Sperren folgen veröffentlichten Regeln, mit Begründung und Einspruchsweg.
- **Transparent:** Festpreis mit offener Aufschlüsselung (Fahrerlohn, Versicherung, fahrbar) statt versteckter Provision.

### Einzelentscheidungen

| # | Thema | Entscheidung |
|---|---|---|
| 1 | Ambition | Side-Projekt mit echtem Pilot: eine Stadt, wenige Nutzer |
| 2 | Protokoll | Open-Source-Plattform jetzt, Protokoll als spätere Vision |
| 3 | Säule | Fahrer-Service zuerst, Carsharing pausiert |
| 4 | Zielgruppe | Heimfahrt nach ambulanten Eingriffen (Sedierung, Augentropfen), vorab gebucht |
| 5 | Vertrauen | Kleines, persönlich geprüftes Fahrerteam; Sperren nur nach offenen Regeln mit Einspruch |
| 6 | Recht | Stufenplan: Gespräche mit Praxen, dann unentgeltliche Testfahrten, rechtliche und versicherungstechnische Aufstellung erst bei bestätigter Nachfrage |
| 7 | Preis | Transparenter Festpreis pro Fahrt, offen aufgeschlüsselt |
| 8 | Zahlung | Rechnung nach der Fahrt, keine In-App-Zahlung im Pilot; Lightning gestrichen |
| 9 | Technik | Flutter-App wird zur Fahrer-App (iOS/Android über TestFlight); Patienten buchen über die Web-Version; Zuteilung von Hand im Admin-Bereich |

## Begründung

- **Ein Protokoll ohne Nutzer ist nur ein Datenbankschema.** Marktplätze leben von Angebot und Nachfrage vor Ort, ohne Föderation bleiben Forks Inseln. Das Anti-Lock-in-Versprechen lässt sich über offenen Code, Datenexport und faire Sperrregeln einlösen.
- **Zwei Marktplätze gleichzeitig heißt vier Seiten kalt starten.** Beim Fahrer-Service bleibt das Auto beim Halter, der Anlass ist konkret und planbar, und ein kleines Fahrerteam reicht.
- **Medizinische Heimfahrten sind planbar und lösen ein echtes Problem.** Nach einer Sedierung darf man 24 Stunden nicht fahren, der Termin steht Tage vorher fest, und Praxen sind ein natürlicher Kanal.
- **„Niemand kann dich aussperren“ ist bei schutzbedürftigen Fahrgästen nicht haltbar.** Unsichere Fahrer müssen ausgeschlossen werden können, aber nie ohne Grund und Einspruch. Das trifft den eigentlichen Kritikpunkt an Uber und Co.
- **Mit angestellten Fahrern gibt es keine Provision.** fahrbar verkauft eine Fahrt; Stripe Connect und die 15 % passen nicht mehr. Lightning bringt der Zielgruppe keinen Nutzen.
- **Fahrer nutzen die App täglich, Patienten einmal.** TestFlight passt für ein kleines Fahrerteam, Patienten sollen nichts installieren müssen.

## Offene Annahme

Akzeptieren Praxen einen fahrbar-Fahrer als Abholung nach einer Sedierung? Das klären die Gespräche mit Praxen vor der ersten Testfahrt.

## Konsequenzen

- Der Carsharing-Code (Inserate, Live-Karte, Stripe-Zahlung) bleibt im Repo, wird aber nicht weiterentwickelt.
- Stripe Connect, die 15 % Plattformgebühr und Lightning entfallen. Die Stripe-Integration ruht mit dem Carsharing.
- Die App bekommt den Fahrer-Service: Buchung im Web, Aufträge und Status in der Fahrer-App, Zuteilung im Admin-Bereich. Fahrten werden vorab gebucht, nicht live auf der Karte gesucht.
- Datensparsamkeit: Gespeichert wird nur, was die Fahrt braucht (Zeit, Abholort, Ziel, Telefon, Kennzeichen), keine Eingriffe oder Diagnosen. Hosting in Deutschland oder der EU.
- fahrbar tritt als „Fahrdienst im eigenen Auto“ auf, nicht als Krankentransport.
- Das README wird an die neue Positionierung angepasst.
