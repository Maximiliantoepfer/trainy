# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run on connected device/emulator
flutter build apk --release  # Android release build
flutter build ipa --release  # iOS release build
flutter analyze              # Run static analysis (uses flutter_lints)
```

No tests exist yet (empty `test/` directory). No CI/CD pipeline configured.

## Architecture

Four-layer pattern: **UI → Provider → Service/DAO → SQLite + Firebase**

- **UI Layer** (`screens/`, `widgets/`): StatelessWidgets using `Consumer<T>` / `context.watch<T>()`
- **Provider Layer** (`providers/`): 7 `ChangeNotifier` classes via `MultiProvider` in `main.dart`
- **Service/DAO Layer** (`services/`): Singleton database services (`ExerciseDatabase.instance`, etc.)
- **Persistence**: SQLite (`trainy.db`, schema v10) as primary store, Firebase Storage for optional cloud backup

Navigation uses `PageView` with `NavigationBar` (4 tabs) — no routing library.

## Key Conventions

- **Language**: All UI strings are hardcoded German in `l10n/app_strings.dart` — no i18n framework
- **IDs**: Timestamp-based (`DateTime.now().millisecondsSinceEpoch`)
- **Models**: Manual `copyWith()` pattern, no code generation (no freezed, no json_serializable, no build_runner)
- **DB Services**: Singleton pattern with private constructor (`static final instance = FooDatabase._()`)
- **DB Migrations**: Idempotent (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE` in try/catch) in `app_database.dart`
- **Theme**: Material 3 with manual color overrides (no `ColorScheme.fromSeed()`), custom accent color persisted in SharedPreferences. Design constants in `themes/app_theme.dart` (border radii: 12/16/20px)
- **State changes**: Always call `notifyListeners()` after mutations in providers
- **Firebase**: Project ID `trainy-39fd1`, config in `firebase_options.dart` (auto-generated)

## Platform Configuration

- Android: minSdk 23, compileSdk/targetSdk 35, App ID `com.example.trainy`
- iOS: Standard Flutter setup
- Web/Desktop: Minimal configuration (experimental)
