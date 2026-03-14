# Trainy – Fitness & Workout Tracker

Eine native Flutter-App für Android und iOS zum Erstellen, Durchführen und Auswerten von Kraft- und Fitnessworkouts. Offline-first, mit optionalem Cloud-Backup über Firebase.

---

## Features

- **Workout-Management** – Workouts erstellen, Übungen per Drag & Drop sortieren
- **Live-Session** – Timer, Set-by-Set-Eingabe, überlebt Navigation zwischen Screens
- **Exercise-Bibliothek** – Konfigurierbare Tracking-Felder (Sets, Reps, Gewicht, Dauer)
- **Fortschritts-Auswertung** – Charts, Wochenziel, Trainingskalender, Session-Details
- **Cloud-Backup** – Google Sign-In → JSON-Backup in Firebase Storage
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

Die App folgt einem klaren vierschichtigen Aufbau:

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
│        Service / DAO-Schicht        │  ← Datenzugriff & Persistence
│  ExerciseDB · WorkoutDB · EntryDB  │
│  SettingsDB · LocalBackupService    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   SQLite (trainy.db)  ←→  Firebase  │  ← Persistenz
└─────────────────────────────────────┘
```

**Pattern:** Models → Services/DAOs → Providers → Screens/Widgets

### Datenfluss

1. App-Start: Providers laden Daten asynchron aus SQLite
2. UI reagiert reaktiv via `Consumer<T>` / `context.watch<T>()`
3. Schreiboperationen laufen über Provider → DAO → SQLite
4. Optional: CloudSyncProvider synchronisiert JSON-Backup mit Firebase Storage

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
├── screens/
│   ├── home_screen.dart                    # Dashboard: Workout-Liste, Wochenübersicht
│   ├── exercise_screen.dart                # Übungsbibliothek mit Suche
│   ├── workout_screen.dart                 # Workout-Editor, Übungen zuordnen/sortieren
│   ├── workout_run_screen.dart             # Live-Session: Timer, Set-Eingabe
│   ├── workout_entry_detail_screen.dart    # Session-Detailansicht
│   ├── progress_screen.dart                # Fortschritts-Übersicht & Charts
│   ├── progress_insights_screen.dart       # Detaillierte Analyse
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
│   ├── app_database.dart                   # SQLite-Setup, Schema v4, Migrations
│   ├── exercise_database.dart              # Exercise CRUD
│   ├── workout_database.dart               # Workout CRUD + Exercise-Zuordnungen
│   ├── workout_entry_database.dart         # Session-Einträge CRUD
│   ├── settings_database.dart              # User-Settings Persistence
│   └── local_backup_service.dart           # Export/Import aller Daten als JSON
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

## Datenbank-Schema (SQLite v4)

### Tabellen

**`exercises`**
| Spalte | Typ | Beschreibung |
|---|---|---|
| id | INTEGER PK | Timestamp-basierte ID |
| name | TEXT | Übungsname |
| description | TEXT | Beschreibung |
| trackedFields | TEXT (JSON) | `{sets, reps, weight, duration}` – Bool-Flags |
| defaultValues | TEXT (JSON) | Vorbelegte Standardwerte |
| lastValues | TEXT (JSON) | Letzte Werte für Auto-Prefill |
| units | TEXT (JSON) | Einheiten pro Feld, z. B. `{"weight": "kg"}` |
| icon | INTEGER? | Material Icon codePoint |

**`workouts`**
| Spalte | Typ | Beschreibung |
|---|---|---|
| id | INTEGER PK | Timestamp-basierte ID |
| name | TEXT | Workout-Name |
| description | TEXT | Beschreibung |

**`exercises_in_workouts`** (N:M-Tabelle)
| Spalte | Typ | Beschreibung |
|---|---|---|
| id | INTEGER PK | Auto-Increment |
| workoutId | INTEGER FK | → workouts (Cascade Delete) |
| exerciseId | INTEGER FK | → exercises (Cascade Delete) |
| sort | INTEGER | Sortierreihenfolge |

**`workout_entries`** (aufgezeichnete Sessions)
| Spalte | Typ | Beschreibung |
|---|---|---|
| id | INTEGER PK | Timestamp-basierte ID |
| workoutId | INTEGER | Zugehöriges Workout |
| exerciseId | INTEGER | Zugehörige Übung |
| timestamp | INTEGER | Unix-Millisekunden |
| valuesJson | TEXT (JSON) | Aggregierte Metriken `{sets, reps, weight, duration}` |
| durationSeconds | INTEGER | Gesamtdauer der Session |

**`user_settings`** (Singleton, id=0)
| Spalte | Typ | Beschreibung |
|---|---|---|
| weekly_goal | INTEGER | Wochenziel (1–7, default 2) |
| sync_enabled | INTEGER | 0/1 Bool |
| last_sync_millis | INTEGER | Zeitstempel des letzten Backups |
| onboarding_done | INTEGER | 0/1 Bool |

### Migrationsstrategie
Schema-Updates sind idempotent (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE` in try/catch). Migration von v1→v4 inkrementell in `onUpgrade`.

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
                   ├─ Aggregiert Sets → einen Eintrag pro Übung
                   └─ INSERT in workout_entries
```

**Session-Persistenz:** Der `ActiveWorkoutProvider` lebt im Provider-Baum – die Session überlebt Navigation und App-Lifecycle-Events.

---

## Cloud-Backup

### Backup-Struktur (Firebase Storage)
```
users/{uid}/backup/
  ├─ latest.json         # Aktuellstes Backup
  └─ {timestamp}.json    # Versionierte Kopien
```

### Sync-Logik
| Trigger | Verhalten |
|---|---|
| App-Start / Resume | Auto-Backup wenn >24h seit letztem Backup |
| Lokale Änderung | Debounced Backup (2s Verzögerung) |
| Periodisch | Check alle 2 Stunden |
| Manuell | Direktes Backup/Restore in Einstellungen |

### Restore-Modi
- **Replace** – Alle lokalen Daten werden durch Cloud-Daten ersetzt
- **Merge** – Cloud-Daten werden zu lokalen Daten zusammengeführt

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
- **Sprache:** Vollständig Deutsch (hardcoded Strings, kein i18n-Framework)
- **IDs:** Timestamp-basiert (`DateTime.now().millisecondsSinceEpoch`)
- **Kein Test-Setup:** Bisher keine Unit- oder Widget-Tests
- **Keine CI/CD:** Kein automatisierter Build-Prozess

---

## Setup

```bash
# Abhängigkeiten installieren
flutter pub get

# App starten
flutter run

# Release-Build (Android)
flutter build apk --release

# Release-Build (iOS)
flutter build ipa --release
```

Firebase-Konfiguration: `google-services.json` (Android) und `GoogleService-Info.plist` (iOS) müssen im jeweiligen Plattformordner liegen (nicht im Repo enthalten).
