# Offline catalog release checklist

1. Check out Free Exercise DB at `a859101d633a01c4a1a920d6a8ce41dabba0705f`.
2. Install the local `cwebp` encoder from libwebp; this is a build-machine
   dependency only and is never included in the mobile app.
3. Fill `catalog_translations_de.json` from the template. Every one of the
   876 `free:<upstream-id>` records must contain a German name, description,
   instructions, search terms and `"reviewed": true` after editorial review.
4. Run:

   ```powershell
   dart run tool/import_free_exercise_db.dart C:\path\to\free-exercise-db tool\catalog_translations_de.json --replace
   ```

5. Re-add `assets/catalog/` and `assets/catalog/images/` to `pubspec.yaml`,
   then run `flutter gen-l10n`, `flutter test` and `flutter build apk --debug`.

The import is atomic. It rejects a changed upstream commit, missing picture,
missing or unreviewed German content, non-876 record count and duplicate IDs.
It keeps the three known image-less upstream records through the local neutral
fallback cover.
