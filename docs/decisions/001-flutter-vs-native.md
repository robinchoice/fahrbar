# ADR 001 — Flutter als primäre Mobile-Plattform

**Status:** Accepted  
**Datum:** 2026-04-17  
**Kontext:** fahrbar + zukünftige Apps

## Kontext

Robin entwickelt parallel eine Flutter-App (fahrbar) und eine Swift-App (döner app). Frage: Welche Strategie macht langfristig mehr Sinn, wenn beide Plattformen (iOS + Android) bedient werden sollen?

Alternativen evaluiert:
- Native Swift (iOS) + Kotlin (Android) — zwei separate Codebases
- Flutter — eine Codebase, beide Plattformen
- Kotlin Multiplatform (KMP) / Compose Multiplatform — geteilte Logik + native UI

## Entscheidung

**Flutter** wird als primäre Plattform für alle zukünftigen Apps verwendet.

## Begründung

**Für Flutter:**
- Eine Codebase für iOS + Android → Hebelwirkung steigt mit jeder weiteren App
- Reusable Component-Bibliothek einmal aufbauen, plattformübergreifend nutzen
- pub.dev-Ecosystem ausgereift (MapBox, Supabase, Stripe etc. alle vorhanden)
- Hot Reload + einheitlicher Toolchain (kein Xcode + Android Studio parallel)
- Performance für Utility/B2C-Apps ausreichend (kompiliert zu nativem ARM)

**Gegen native Swift/Kotlin parallel:**
- Doppelter Aufwand bei Features, Bugfixes, Upgrades
- SwiftUI + Compose teilen zwar das deklarative Paradigma, sind aber nicht kompatibel
- Kein Synergieeffekt bei Component-Bibliotheken

**Warum nicht KMP:**
- Compose Multiplatform iOS erst seit Mai 2024 stable — zu jung für Production-Bet
- Ecosystem (Packages) deutlich dünner als pub.dev
- Tooling noch nicht ausgereift (Xcode + Android Studio weiterhin nötig)
- Hot Reload schwächer als Flutter
- Neu bewerten: 2028 oder wenn KMP-Ecosystem signifikant gewachsen ist

## Ausnahmen

Native bleibt sinnvoll wenn ein Feature es erzwingt:
- Live Activities / Dynamic Island (iOS-exklusiv, Flutter-Support verzögert)
- HealthKit-Tiefe Integration
- Wear OS / watchOS

In diesen Fällen: Platform Channel in Flutter, nativen Code nur für das spezifische Feature.

## Konsequenzen

- döner app (Swift) wird als Lernprojekt fertiggestellt, nicht als strategische Plattform
- Alle neuen Apps starten als Flutter-Projekt
- Component-Bibliothek (`packages/`) in fahrbar oder eigenem Repo aufbauen sobald Patterns sich wiederholen
