# fahrbar — Setup

## Bevor du anfängst

### 1. Flutter installieren
```bash
brew install --cask flutter
flutter doctor
```
Alle Haken grün kriegen (Xcode, Android SDK, etc.).

### 2. Flutter-Projekt scaffolden
```bash
cd ~/dev/fahrbar
flutter create . --org de.fahrbar --platforms ios,android,web
```

### 3. Pakete eintragen (pubspec.yaml)
```yaml
dependencies:
  flutter_riverpod: ^2.6.1
  go_router: ^14.0.0
  supabase_flutter: ^2.8.0
  flutter_map: ^7.0.0             # MapLibre-kompatibel, FOSS
  latlong2: ^0.9.1
  geolocator: ^13.0.0
  image_picker: ^1.1.2
  flutter_stripe: ^10.2.0
  shared_preferences: ^2.3.3
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.8.0
```

### 4. Supabase (lokale Dev-Instanz)
```bash
brew install supabase/tap/supabase
supabase init
supabase start
```

### 5. Externe Accounts (einmalig)
- [ ] Stripe Connect beantragen → https://dashboard.stripe.com/connect
- [ ] Apple Developer Account (99 USD/Jahr)
- [ ] Google Play Developer (25 USD einmalig)

## Starten
```bash
flutter run -d chrome          # PWA
flutter run -d ios             # iOS Simulator
flutter run -d android         # Android Emulator
```
