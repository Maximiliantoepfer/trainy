# Offline catalog release checklist

1. Check out Free Exercise DB at `a859101d633a01c4a1a920d6a8ce41dabba0705f`.
2. Install either the local `cwebp` encoder from libwebp or Python with
   Pillow. These are build-machine dependencies and are never included in the
   mobile app.
3. Optionally fill `catalog_translations_de.json` from the template. Reviewed
   German fields use `"reviewed": true`. Missing German records deliberately
   fall back to the complete English original and are marked with
   `"reviewed": false` and `"fallbackLocale": "en"`.
4. Run:

   ```powershell
   dart run tool/import_free_exercise_db.dart C:\path\to\free-exercise-db tool\catalog_translations_de.json --replace
   ```

5. Run `dart run tool/apply_catalog_release.dart` to merge the curated additions.
   Verify 887 records: 876 pinned Free Exercise DB records plus eleven owned
   `trainy:` entries (five activities, two mobility and four strength exercises).
   The importer retains owned entries; `catalog_essentials.json` also keeps the
   concrete additions reproducible. `assets/catalog/` is registered in `pubspec.yaml`.
6. Run `flutter gen-l10n`, `flutter analyze`, `flutter test` and
   `flutter build apk --debug`.

The import is atomic. It rejects a changed upstream commit, an invalid image,
missing English content, a non-876 upstream record count and duplicate IDs.
It keeps the three known image-less upstream records through the local neutral
fallback cover. The manifest separately records reviewed German translations
and explicit English fallbacks, plus asset checksums and the pinned commit.

`trainy:mobility_session` is intentionally not generated. Concrete Free-DB
mobility exercises are shown instead; the five broad Trainy records are kept
in the separate activity area.
