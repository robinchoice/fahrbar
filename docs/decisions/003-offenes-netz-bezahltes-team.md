# ADR 003 — Geschäftsmodell: offenes Netz, bezahltes Team

**Status:** Accepted  
**Datum:** 2026-10-02  
**Kontext:** fahrbar — Workshop zum Geschäftsmodell

## Kontext

ADR 002 hat fahrbar auf einen Fahrer-Service-Pilot in Freiburg ausgerichtet. Offen blieb, wovon fahrbar lebt, ob sich der Pilot rechnet und was von der Idee eines offenen Mobilitätsnetzes im Cypherpunk-Sinn bleibt. Ein zweiter Workshop hat das durchgespielt. Dieses ADR hält das Ergebnis fest und löst die Teile von ADR 002 ab, die sich ändern.

## Entscheidung

Das Leitbild ist ein **offenes Netz nach dem Vorbild von Vexl**: Vertrauen entsteht über Bekannte, Fahrtdaten sind Ende-zu-Ende verschlüsselt, das Vermitteln kostet nichts. **Geld verdient ein geprüftes Team**, das in diesem Netz als Anbieter auftritt und Fahrten zum Festpreis verkauft. Nach dem Pilot kommt **privates Carsharing mit einer Gruppenversicherung** dazu, für die eine Gebühr anfällt.

### Einzelentscheidungen

| # | Thema | Entscheidung |
|---|---|---|
| 1 | Leitbild | Offenes Netz wie Vexl: Vertrauen über Bekannte, Schlüssel statt Konten, Ende-zu-Ende-Verschlüsselung, keine Vermittlungsgebühr |
| 2 | Einnahmen | Das geprüfte Team verkauft Fahrten zum Festpreis, im Pilot 49 €. Das Vermitteln bleibt gratis |
| 3 | Reihenfolge | Pilot zuerst, aber von Anfang an mit Schlüsseln statt Konten und Ende-zu-Ende-verschlüsselten Fahrtdaten, damit das Team später ohne Umbau ins Netz passt |
| 4 | Auslastung | Mehrere Abholungen pro Schicht statt Einzelfahrten. Zurück zur Praxis geht es mit dem Klapp-E-Scooter aus dem Kofferraum |
| 5 | Dichte | Eine Partnerpraxis legt Patienten ohne Begleitung auf zwei feste fahrbar-Vormittage pro Woche. Sie verteilt nur den Buchungslink und gibt keine Patientendaten weiter |
| 6 | Fahrer | Robin fährt selbst, die Bekannten aus den Testfahrten springen ein. Ein Minijobber kommt dazu, sobald ein Vormittag vier Wochen in Folge mindestens drei Abholungen hatte |
| 7 | Zahlung | Bar und vorher abgezählt im Umschlag, gegen eine Quittung ohne Namen aus einem nummerierten Quittungsblock. Rechnung nur als Ausnahme |
| 8 | Software im Pilot | Ein Buchungsformular im Web, dessen Fahrtdaten nur das Team lesen kann, und eine Liste pro Vormittag. Keine Fahrer-App, kein Admin-Bereich |
| 9 | Carsharing | Privates Carsharing mit Gruppenversicherung gegen Gebühr, gebaut nach dem Pilot. Ob ein Versicherer mitmacht, klärt vorher das Makler-Gespräch für die Team-Versicherung |

## Begründung

- **Eine Gebühr fürs Vermitteln lässt sich nicht halten.** Um sie durchzusetzen, müsste fahrbar jede Fahrt sehen. Wer seinen Fahrer kennt, bucht beim nächsten Mal direkt, und der erste Fork verzichtet auf die Gebühr. fahrbar verdient deshalb an dem, was sich nicht kopieren lässt: an geprüften Fahrern, die verlässlich kommen, und später an einer Versicherung.
- **Das Team löst das Netz-Paradox.** Wer nach einer Sedierung jemanden aus dem Bekanntenkreis hat, braucht fahrbar nicht. Gerade wer dieses Netz nicht hat, bucht das Team.
- **Einzelfahrten rechnen sich nicht.** Pro Fahrt ist ein Fahrer 1,5 bis 2 Stunden unterwegs. Nach Mindestlohn (13,90 €), rund 30 % Minijob-Abgaben und Bus und Bahn für den Weg bleiben von 49 € nur 7 bis 16 €. Ohne feste Tagesarbeitszeit im Vertrag sind bei Arbeit auf Abruf pro Einsatz mindestens drei Stunden zu bezahlen (§ 12 TzBfG). Dann bringt jede Einzelfahrt Verlust.
- **Schichten mit mehreren Abholungen rechnen sich.** Eine Schicht von vier Stunden kostet rund 72 €. Bei drei Abholungen bleiben pro Fahrt etwa 25 €, bei vier etwa 31 €, jeweils vor Versicherung und Hosting. Die nötige Dichte entsteht nicht von selbst, deshalb bündelt die Praxis die Termine.
- **Feste Vormittage sind Fixkosten.** Vertraglich feste Stunden sind auch dann zu bezahlen, wenn sie nicht abgerufen werden. Bis die Vormittage voll sind, trägt deshalb eigene Zeit das Risiko statt eines Lohns.
- **Bargeld ist das Cypherpunk-Geld, das Patienten schon haben.** Es hinterlässt keine Spur auf dem Konto, kostet keine Gebühren und erzeugt keine offenen Rechnungen. Nach einer Sedierung sollen Patienten bis zum nächsten Tag nichts Rechtsverbindliches unterschreiben. Weil der Betrag vorher feststeht und bereitliegt, muss an der Haustür niemand etwas entscheiden. Bis 250 € braucht eine Rechnung keinen Kundennamen (§ 33 UStDV).
- **Das Recht begrenzt das Netz.** Für Mitfahrten dürfen Privatleute höchstens die Betriebskosten verlangen (§ 1 Abs. 2 Nr. 1 PBefG). Ein Uber mit Privatfahrern, die daran verdienen, ist ausgeschlossen. Ein Fahrer im Auto des Kunden ist nach bisherigem Stand keine genehmigungspflichtige Personenbeförderung.
- **Carsharing braucht einen Versicherer.** Wer sein Auto gegen Geld an Fremde vermietet, riskiert den Schutz der eigenen Kfz-Versicherung. Eine Gruppenversicherung kann kein Fork kopieren, deshalb ist eine Gebühr dafür vertretbar.

## Offene Annahmen

Vor dem bezahlten Start müssen diese Gespräche klären:

- **Praxen:** Akzeptieren sie einen fahrbar-Fahrer als Abholung nach einer Sedierung? Wie viele Patienten pro Woche kommen ohne Begleitung und könnten mit dem eigenen Auto kommen? Würden sie diese Patienten auf zwei Vormittage legen? Kostet sie ein geplatzter Sedierungstermin Geld? Würden die Patienten 49 € zahlen?
- **Makler:** Was kostet die Versicherung für Schäden am Kundenauto? Zeichnet ein Versicherer eine Gruppenversicherung für privates Carsharing, und zu welchem Preis?
- **Anwalt:** Ist der Fahrer im Kundenauto wirklich keine genehmigungspflichtige Personenbeförderung? Braucht die Carsharing-Versicherung eine Erlaubnis nach § 34d GewO?

**Messlatte:** Mit bezahlten Fahrern deckt ein Vormittag ab zwei Abholungen seine Kosten, Gewinn bringt er ab drei. Hat keine Praxis mindestens vier bis sechs passende Patienten pro Woche, fehlt dem Modell die Grundlage.

## Konsequenzen

- Versicherte Vermietungen sind die Ausnahme vom Vexl-Prinzip. Der Versicherer will Identität, Führerschein und Zeitraum jeder Vermietung kennen, fahrbar sieht dann also Mieter, Auto und Zeitraum. Anonym bleibt nur das Leihen unter Bekannten ohne Versicherung.
- Mit dem Carsharing wird fahrbar zum Betreiber: Rahmenvertrag mit einem Versicherer, Schäden, Streit zwischen Halter und Mieter, Kautionen und Betrug.
- Minijob-Verträge brauchen feste Wochen- und Tagesstunden. Fehlen sie, sind pro Einsatz mindestens drei Stunden zu bezahlen, und 20 Stunden pro Woche gelten als vereinbart (§ 12 TzBfG).
- Bareinnahmen werden einzeln aufgezeichnet. Der Durchschlag des Quittungsblocks reicht dafür.
- In der Buchungsbestätigung steht: „Bitte 49 € abgezählt im Umschlag bereitlegen.“

### Was sich gegenüber ADR 002 ändert

| ADR 002 | ADR 003 |
|---|---|
| Rechnung nach der Fahrt per Überweisung | Bar und vorher abgezählt, Quittung ohne Namen |
| Die Flutter-App wird zur Fahrer-App, Zuteilung im Admin-Bereich | Im Pilot weder Fahrer-App noch Admin-Bereich |
| Carsharing ruht, der Stripe-Code bleibt im Repo | Carsharing mit Gruppenversicherung nach dem Pilot, Stripe ist seit 2026-10-01 entfernt |
| Ein Protokoll bleibt spätere Vision | Leitbild ist ein offenes Netz nach dem Vorbild von Vexl, nach dem Pilot |
