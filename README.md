# Trainy – Fitness & Workout Tracker

Eine native Flutter-App für Android und iOS zum Erstellen, Durchführen und Auswerten von Kraft- und Fitnessworkouts. Offline-first, mit optionalem Cloud-Backup über Firebase.

---

## Features

- **Workout-Management** – Workouts erstellen, Übungen per Drag & Drop sortieren
- **Live-Session** – Timer, Set-by-Set-Eingabe, überlebt Navigation zwischen Screens
- **Exercise-Bibliothek** – Konfigurierbare Tracking-Felder (Sets, Reps, Gewicht, Dauer)
- **Fortschritts-Auswertung** – Charts, Wochenziel, Trainingskalender, Session-Details
- **Cloud-Backup** – Google Sign-In → geprüftes v2-ZIP in Firebase Storage
- **Individuelles Theme** – Light/Dark/System + freie Akzentfarbenauswahl

---

## Tech-Stack

| Bereich | Technologie |
|---|---|
| Framework | Flutter 3 / Dart 3.7+ |
| Design System | Material 3 |
| State Management | Provider 6 (ChangeNotifier) |
| Lokale Datenbank | SQLite via sqflite |
| Cloud | Firebase Auth + Firebase Storage |
| Charts | fl_chart + Custom Painter |
| Sonstiges | shared_preferences, flutter_colorpicker, flutter_speed_dial, intl |

---

## Architektur

Die App stellt auf einen vierschichtigen Aufbau um. Neue Epoch-2-Funktionen
verwenden Repositories; bestehende Oberflächen laufen bis zu ihrer fachlichen
Umstellung über eine klar markierte Kompatibilitätsfassade in derselben
`trainy_v2.db`:

```
┌─────────────────────────────────────┐
│           Screens & Widgets         │  ← UI-Schicht (StatelessWidget / Consumer)
└──────────────┬──────────────────────┘
               │ context.watch / context.read
┌──────────────▼──────────────────────┐
│         Provider-Schicht            │  ← State & Business Logic (ChangeNotifier)
│  Exercise · Workout · Progress      │
│  ActiveWorkout · CloudSync · Theme  │
└──────────────┬──────────────────────┘
               │ async/await
┌──────────────▼──────────────────────┐
│       Repository-/Service-Schicht   │  ← Transaktionen & Persistence
│ Exercise · Workout · Activity       │
│ TrainingPlan · Database · Backup   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│ SQLite (trainy_v2.db) ←→ Firebase   │  ← Persistenz
└─────────────────────────────────────┘
```

**Ziel-Pattern:** Models → Repositories → Providers → Screens/Widgets

### Datenfluss

1. App-Start: Der Lifecycle-Koordinator prüft Datenepoch und Integrität
2. UI reagiert reaktiv via `Consumer<T>` / `context.watch<T>()`
3. Neue Schreiboperationen laufen transaktional über Repositories nach SQLite
4. Optional: CloudSyncProvider synchronisiert ein versioniertes ZIP-Backup mit Firebase Storage

---

## Projektstruktur

```
lib/
├── main.dart                               # App-Bootstrap, Firebase-Init, MultiProvider
├── firebase_options.dart                   # Auto-generiert (FlutterFire CLI)
│
├── models/
│   ├── exercise.dart                       # Übung (Tracking-Flags, Default/Last-Values, Einheiten)
│   ├── workout.dart                        # Workout-Template (Name, geordnete Exercise-IDs)
│   └── workout_entry.dart                  # Aufgezeichnete Session (Metriken als JSON-Map)
│
├── providers/                              # State Management (ChangeNotifier)
│   ├── exercise_provider.dart              # Exercise CRUD & Cache
│   ├── workout_provider.dart               # Workout CRUD & Cache
│   ├── progress_provider.dart              # Fortschritt, Wochenziel, Aggregation
│   ├── active_workout_provider.dart        # Laufende Session (In-Memory + Ticker-Timer)
│   ├── cloud_sync_provider.dart            # Firebase Auth, Backup/Restore
│   ├── theme_provider.dart                 # ThemeMode + Akzentfarbe (SharedPreferences)
│   └── locale_provider.dart               # Sprachauswahl (SharedPreferences)
│
├── repositories/                           # Fachliche Transaktionen auf Datenepoch 2
│   ├── exercise_repository.dart            # Katalogmaterialisierung, Tags, Merge/Undo
│   ├── workout_repository.dart             # Dauerhafte Workout-Vorlagen und Varianten
│   ├── training_plan_repository.dart       # Unabhängige Plan-/Workout-Zuordnung
│   └── activity_repository.dart            # Sessions, Efforts und typisierte Messwerte
│
├── screens/
│   ├── home_screen.dart                    # Dashboard: Workout-Liste, Wochenübersicht
│   ├── exercise_screen.dart                # Übungsbibliothek mit Suche
│   ├── workout_screen.dart                 # Workout-Editor, Übungen zuordnen/sortieren
│   ├── workout_run_screen.dart             # Live-Session: Timer, Set-Eingabe
│   ├── workout_entry_detail_screen.dart    # Session-Detailansicht
│   ├── progress_screen.dart                # Fortschritts-Übersicht & Charts
│   └── settings_screen.dart               # Einstellungen, Theme, Cloud-Sync
│
├── widgets/
│   ├── onboarding_gate.dart                # Onboarding-Flow / Auth-Gate
│   ├── active_workout_banner.dart          # Schwebender Banner für laufende Session
│   ├── workout_card.dart                   # Workout-Listenelement
│   ├── trainings_calendar.dart             # Kalenderansicht
│   ├── weekly_activity_chart.dart          # Wöchentlicher Aktivitäts-Balkendiagramm
│   ├── filtered_exercise_progress_chart.dart # Übungs-Fortschritts-Liniendiagramm (Custom Painter)
│   └── app_title.dart                      # App-Titel-Widget
│
├── services/
│   ├── app_database.dart                   # Verbindung, FK- und Integritätsprüfung
│   ├── database_schema_v2.dart             # Kanonisches Epoch-2-Schema
│   ├── data_lifecycle_coordinator.dart      # Epochreset und lokale Löschung
│   ├── exercise_database.dart              # Exercise CRUD
│   ├── workout_database.dart               # Workout CRUD + Exercise-Zuordnungen
│   ├── workout_entry_database.dart         # Session-Einträge CRUD
│   ├── settings_database.dart              # User-Settings Persistence
│   └── local_backup_service.dart           # Geprüftes, versioniertes ZIP-Backup
│
├── navigation/
│   └── main_navigation.dart               # Bottom Nav (4 Tabs, PageView-basiert)
│
├── themes/
│   └── app_theme.dart                     # Material 3 Theme (Light & Dark)
│
└── utils/
    ├── duration_utils.dart                 # Dauer-Formatierung
    └── utils.dart                          # Allgemeine Hilfsfunktionen
```

---

## Datenbank-Schema (Datenepoch 2)

### Tabellen

| Gruppe | Zentrale Tabellen | Zweck |
|---|---|---|
| Referenzen | `app_meta`, `tag_definitions`, `metric_definitions` | Epoch-/Schema-Metadaten und stabile Codes |
| Übungen | `exercise_items`, `exercise_tags`, `exercise_metric_configs`, `exercise_images_v2` | Katalogreferenzen, eigene Inhalte und frei kombinierbare Metriken |
| Profile | `training_profiles_v2`, `training_profile_equipment` | Normalisierte verfügbare Ausstattung |
| Workouts | `workout_templates`, `workout_variants_v2`, `workout_groups_v2`, `workout_slots_v2` | Dauerhafte Vorlagen und Profil-/Variantenlogik |
| Pläne | `training_plans`, `training_plan_workouts` | Plan-Zuordnung ohne Besitz der Workout-Vorlage |
| Aktivitäten | `activity_sessions`, `activity_items`, `activity_efforts`, `activity_metric_values` | Unveränderliche Ausführungssnapshots und typisierte Messwerte |
| Integration | `health_record_links` | Stabile Verweise für spätere Health-Connect-/HealthKit-Synchronisierung |
| Deduplizierung | `duplicate_suggestions_v2`, `exercise_redirects_v2` | Persistente Vorschläge und reversible Weiterleitungen |

### Migrationsstrategie

Epoch 2 verwendet `trainy_v2.db`, UUID-Text-IDs, normalisierte Tags/Metriken
und ein gemeinsames Aktivitätsmodell für Kraft, Cardio und Mobilität. Beim
ersten Start wird die alte Trainingsdatenbank bewusst verworfen. Der Marker
wird erst nach erfolgreichem `integrity_check` und `foreign_key_check`
geschrieben; ein unterbrochener Reset wiederholt sich dadurch sicher.

`PRAGMA foreign_keys = ON` wird für jede Verbindung in `onConfigure` gesetzt.
Das kanonische Schema steht in `lib/services/database_schema_v2.dart`. Einige
leere Kompatibilitätstabellen halten die vorhandenen Screens während der
schrittweisen Repository-Umstellung funktionsfähig und werden entfernt, sobald
kein Screen mehr auf die alten Integer-DAOs zugreift.

---

## Design System

### Material 3

Die App nutzt Material 3 mit bewussten Abweichungen für mehr Kontrolle über die visuelle Ausgabe:

- **Kein `ColorScheme.fromSeed()`** – stattdessen manuelle Überschreibung von primary/secondary mit der exakten Akzentfarbe, um sicherzustellen, dass UI-Elemente exakt der Nutzerauswahl entsprechen (kein tonales Rauschen)
- **Keine Elevation-Overlays im Dark Mode** (`applyElevationOverlayColor: false`) für cleane, flache Oberflächen
- **Surface Tint deaktiviert** auf Cards und Dialogen

### Farben

| | Light | Dark |
|---|---|---|
| Scaffold | `#FFFFFF` | `#0B0B0D` |
| Card-Hintergrund | `#F7F7F8` | `#121316` |
| Akzentfarbe (Standard) | `#4776F8` | `#4776F8` |
| Akzentfarbe | Frei wählbar via Color Picker | Frei wählbar via Color Picker |

### Typografie

| Style | Größe | Gewicht | Tracking |
|---|---|---|---|
| titleLarge | 22px | w700 | −0.2 |
| titleMedium | 18px | w600 | — |
| bodyLarge | 16px | — | — |
| bodyMedium | 15px | — | — |
| labelMedium | 13px | — | — |

### Komponenten-Entscheidungen

- **Cards & Dialoge:** 20px Border-Radius, Elevation 0, kein Surface Tint
- **Buttons:** 14px Border-Radius, volle Akzentfarbe, keine Elevation
- **Input-Felder:** surfaceVariant-Fill, Primärfarbe bei Fokus
- **Chips:** 999px Border-Radius (Pill-Form), neutrale Farbe
- **Bottom Navigation:** Icons 26px (normal) / 32px (aktiv), kein Ripple, kein Indicator-Hintergrund, Labels ausgeblendet

---

## Navigation

```
Bottom Navigation (4 Tabs, PageView-basiert)
├── Tab 1: Home       – Workouts & Wochenübersicht
├── Tab 2: Übungen    – Exercise-Bibliothek
├── Tab 3: Fortschritt – Charts & Analytics
└── Tab 4: Einstellungen – Theme, Cloud-Sync
```

- **PageView** mit `BouncingScrollPhysics` für natürliches Scrollverhalten
- **Seitenübergang:** 280ms, `easeOutCubic`-Kurve
- **Kein pushNamed-Routing** für Haupttabs – direkte PageView-Steuerung

---

## Workout-Session Flow

```
HomeScreen
  └─► WorkoutScreen (Workout auswählen / bearbeiten)
        └─► WorkoutRunScreen (Live-Session starten)
              │
              ├─ ActiveWorkoutProvider.start()
              │    ├─ Timer (1s-Ticker, screen-unabhängig)
              │    └─ In-Memory Set-Liste pro Übung
              │
              ├─ Nutzer gibt Sets ein (Reps/Gewicht/Dauer)
              │
              └─ Speichern → ProgressProvider.saveSession()
                   └─ derzeit Kompatibilitätsfassade; Zielmodell:
                        ActivitySession → Items → Efforts → Metrics
```

**Session-Persistenz:** Der `ActiveWorkoutProvider` lebt im Provider-Baum – die Session überlebt Navigation und App-Lifecycle-Events.

Die normalisierte Activity-API ist bereits vorhanden und schemaseitig
abgesichert. Die bestehende Kraft-UI wird separat auf diese API umgestellt;
bis dahin werden ihre historischen Integer-Tabellen nicht als neue öffentliche
Schnittstelle erweitert.

---

## Cloud-Backup

### Backup-Struktur (Firebase Storage)
```
users/{uid}/backups/v2/
  ├─ latest.zip         # Aktuellstes vollständiges v2-Backup
  └─ {timestamp}.zip    # Versionierte Kopien
```

### Sync-Logik
| Trigger | Verhalten |
|---|---|
| App-Start / Resume | Auto-Backup nur bei ausdrücklich aktivierter Synchronisierung |
| Lokale Änderung | Debounced Backup nach relevanten Änderungen |
| Periodisch | Check alle 2 Stunden, solange Sync aktiviert ist |
| Manuell | Vollständiges Backup oder validierter Vollrestore |

### Restore-Verhalten

Backups enthalten Manifest, Datenepoch, Schema-/Katalogversion, Tabellen,
persönliche Bilder und Prüfsummen. Vor einem Restore werden Pfade,
Größenlimits, Checksummen und Fremdschlüssel in einer temporären Datenbank
geprüft. Erst dann ersetzt das Backup die lokale Datenbank als Ganzes. Ein
zeilenweises Zusammenführen sowie v1-/JSON-Backups werden bewusst nicht mehr
unterstützt.

---

## Lokale Provider-Übersicht

| Provider | Verantwortlichkeit |
|---|---|
| `ExerciseProvider` | Exercise CRUD, alphabetische Sortierung, lastValues-Update |
| `WorkoutProvider` | Workout CRUD, Exercise-Zuordnungen, Sortierung |
| `ProgressProvider` | Session-Aggregation, Wochenziel, Eintrags-History |
| `ActiveWorkoutProvider` | Live-Session State, 1s-Timer, Set-Verwaltung |
| `CloudSyncProvider` | Firebase Auth (Google), Backup/Restore, Auto-Sync |
| `ThemeProvider` | ThemeMode (System/Light/Dark), Akzentfarbe |
| `LocaleProvider` | Sprachauswahl |

---

## Plattformen

| Plattform | Status |
|---|---|
| Android | Primär unterstützt |
| iOS | Unterstützt |
| Web | Konfiguriert (experimentell) |
| Windows / macOS / Linux | Minimal konfiguriert |

---

## Hinweise zum Projekt

- **Offline-first:** Die App funktioniert vollständig ohne Cloud-Verbindung
- **Sprache:** Deutsch und Englisch über lokale ARB-Dateien und Flutter `gen-l10n`; die Auswahl kann dem System folgen
- **IDs:** Kanonische v2-Entitäten verwenden UUID v4; die alte UI-Fassade bleibt nur während der Umstellung Integer-basiert
- **Tests:** Unit- und Widget-Tests für Lokalisierung, Katalog-/Zielregeln, Icons und kritische Modal-Flows
- **Keine CI/CD:** Kein automatisierter Build-Prozess

---

## Setup

```bash
# Abhängigkeiten installieren
flutter pub get

# Lokalisierungscode erzeugen
flutter gen-l10n

# Statische Analyse und vollständige Tests
flutter analyze
flutter test

# App starten (bei genau einem angeschlossenen Zielgerät)
flutter run

# App auf einem konkreten Gerät starten
flutter devices
flutter run -d <device-id>

# Debug-Build als lokales Abschluss-Gate
flutter build apk --debug

# Release-Build (Android)
flutter build apk --release

# Release-Build (iOS)
flutter build ipa --release
```

### Android-Debug-Gerät

Trainy ist nicht an ein bestimmtes Emulator- oder Pixel-Modell gebunden. In
Android Studio wird das gewünschte laufende Gerät im Geräte-Dropdown gewählt.
Wenn mehrere Ziele verbunden sind, sollte im Terminal eine konkrete Geräte-ID
angegeben werden. Emulator-Ports können sich nach einem Neustart ändern:

```powershell
adb devices -l
adb -s <device-id> shell getprop ro.boot.qemu.avd_name
C:\flutter\bin\flutter.bat run -d <device-id>
```

Bei Android-Startproblemen kann die optionale Smoke-Prüfung zusätzlich APK-
Paket, Launcher-Activity und DEX-Klasse validieren, das APK installieren und
die Activity direkt starten. `ExpectedAvdName` ist dabei eine gezielte
Diagnosehilfe und keine Produktbeschränkung:

```powershell
.\tool\verify_android_launch.ps1 -DeviceId <device-id> -ExpectedAvdName <avd-name>
```

### Firebase-Datenschutzkonfiguration

Cloud-Backups liegen ausschließlich unter `users/{uid}/backups/v2/` und
werden durch `storage.rules` auf den angemeldeten UID-Inhaber begrenzt. Regeln
und die deklarierte Delete-User-Data-Extension werden vor einem Release
explizit ausgerollt:

```powershell
firebase deploy --only storage,extensions --project trainy-39fd1
```

Die Extension löscht nach einem Auth-Delete als zusätzliche Absicherung
`{DEFAULT}/users/{UID}`. Die App versucht diese Löschung bereits vorher und
kann einen unterbrochenen lokalen Abschluss über einen persistenten Marker
fortsetzen. Die versionierte Datei `extensions/delete-user-data.env` enthält
nur nicht-geheime Extension-Parameter; persönliche `.env`-Dateien bleiben
weiterhin ignoriert.

### Versionskontrolle

- ARB-Dateien, `lib/l10n/generated`, `pubspec.lock`, Flutter-
  Plugin-Registranten und benötigte Tool-Assets werden versioniert.
- Build-, Cache-, Recovery- und temporäre Importausgaben bleiben ignoriert.
- Neue oder lokal geänderte Schlüssel, `.env`-Dateien und Signing-Dateien
  dürfen nicht committed werden.
- Zeilenenden werden über `.gitattributes` festgelegt; bestehende Dateien
  werden nicht massenhaft renormalisiert.

Firebase-Konfiguration: `google-services.json` (Android) und
`GoogleService-Info.plist` (iOS) müssen im jeweiligen Plattformordner liegen.
Private Signing-Schlüssel und lokale Umgebungsdateien werden nicht versioniert.
