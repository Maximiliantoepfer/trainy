# Workout-Editor v5

## Verhalten und Datenhaltung

- Alle Gruppen verwenden volle Inhaltsbreite mit 16 dp Außenabstand. Leere
  Gruppen bleiben kompakte Drop-Ziele ohne zusätzlichen Hinweistext.
- Titel antippen zum Umbenennen. Langdruck startet die Mehrfachauswahl;
  Antippen, letzte Abwahl, Schließen, Zurück und Setupwechsel beenden bzw.
  aktualisieren sie. Die untere Aktionsleiste reserviert eigenen Platz.
- Aufwärmen und Cooldown sind fest verankert. Die mittlere Gruppenreihenfolge
  gilt für alle Setups; ihre Übungen bleiben unabhängig. Die leere Kerngruppe
  wird bei eigenen Gruppen ausgeblendet, beim Übungsdrag temporär eingeblendet.
- Ziehgriffe starten ohne Langdruck. Einfügepositionen, Randscrollen und
  zusätzliche Screenreader-Verschiebeaktionen werden unterstützt.
- Sortieren, Verschieben, Gruppieren und Pflicht/Optional-Änderungen werden
  transaktional gespeichert und auf die aktuelle Setup-Zugehörigkeit geprüft.
  Bei Fehlern bleibt der vorherige Stand sichtbar. Ein fehlgeschlagener Refresh
  wiederholt keine bereits erfolgreich gespeicherte Erstellung.
- Im Training erscheinen lokalisierte Gruppen als Abschnitte. Leere Gruppen
  entfallen; optionale Übungen bleiben über den Abschnitt aktivierbar.
- Editor und Training verwenden denselben vollständigen Offline-Picker.
  Label-Filter starten bei Alle. Familie und Equipment ändern nur die
  Priorisierung, nicht die Verfügbarkeit. Katalogzeilen werden bei Auswahl
  materialisiert; vorhandene lokale Katalogzeilen erscheinen nicht doppelt.
- Austausch gilt nur für die laufende Session. Nach erfassten Sätzen bleibt
  ein Austausch gesperrt, damit Historie und PRs nicht umgehängt werden.

## Schema und Wiederaufnahme

Datenepoch **2** bleibt bestehen. Schema **4 → 5** ergänzt ausschließlich:

- `activity_session_groups.plan_snapshot`: Gruppenart, stabile Quell-ID,
  Varianten, Slots und Alternativen in ihrer gespeicherten Reihenfolge.
- `activity_sessions.selection_snapshot`: aktive Übungen, Gruppen- und
  Slotauswahl sowie aktivierte optionale Slots.

Die gemeinsame Gruppenreihenfolge wird normalisiert. Historische Sessions
werden nicht umsortiert. Ältere aktive Sessions ohne Gruppensnapshot bleiben
in der bisherigen flachen Reihenfolge lesbar. Neue Sessions werden mit ihren
Auswahlen lokal wiederhergestellt. Cloud-Zugriffe sind dafür nicht notwendig.

ZIP-Backups mit Schema 4 (`2026-10-16.4`) werden in einer temporären
Schema-5-Datenbank eingelesen, ergänzt und per Integritäts-/FK-Prüfung validiert,
bevor sie die aktive Datenbank ersetzen. Andere inkompatible Versionen bleiben
abgewiesen. Es gibt keinen Hard Reset.

## Prüfungen

```powershell
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --debug
```

Regressionstests liegen in `test/workout_editor_v5_repository_test.dart`,
`test/workout_editor_v5_widget_test.dart`, `test/workout_exercise_picker_test.dart`,
`test/workout_run_groups_test.dart` und `test/workout_v5_backup_test.dart`.
Sie prüfen unter anderem SQLite-Rollback, Setup-Isolation, Schema-Upgrade,
Session-Wiederaufnahme, Backup-Validierung, Auswahl-/Drag-Lifecycles,
Randscrollen, große Schrift sowie Suchergebnisse jenseits von 80 Treffern.

Die Screenshotreferenzen in `test/goldens` prüfen Geometrie und Farben mit
Flutter-Testschriften. Vor der Aufnahme wird das Muskelarm-Asset ausdrücklich
vorgeladen. Testfehlerbilder und lokale Android-Abnahmebilder werden nicht
versioniert (`test/failures`, `build/qa-v5`). Änderungen an Referenzbildern
immer visuell prüfen; nicht ungeprüft mit `--update-goldens` übernehmen.

Manuelle Android-Abnahme: Titel ändern, Mehrfachauswahl/Abwahl, Gruppieren,
Griff-Drag in leere Gruppen, korrekte Abschnittsreihenfolge im Training,
Katalogtausch, Prozessneustart und Wiederaufnahme. Bestehende Nutzerworkouts
nicht als veränderliche Testfixtures verwenden.

Gedrückthalten zum Beenden des Trainings gehört ausdrücklich nicht zu v5.

### Abnahme am 16.10.2026

- `gen-l10n`, Analyse, 63 Tests und Debug-APK erfolgreich.
- Android-Emulator: vorhandene Workouts nach Upgrade erhalten; getrennten
  `QA-v5-smoke` angelegt und umbenannt. Mehrfachauswahl, letzte Abwahl,
  Gruppieren und Verschieben in Aufwärmen geprüft.
- Temporäre Kern-Dropzone verschwindet nach erfolgreichem Ablegen wieder.
- Session zeigt Aufwärmen vor Brust, lässt leere Gruppen aus und findet
  `Zottman Curl` im vollständigen Katalogpicker.
- Austausch und Satz (8 Wiederholungen / 5 kg) nach Force-stop und Neustart
  erfolgreich wiederaufgenommen; Vorlage behält ihre ursprüngliche Übung.
- Der QA-Workout und seine unvollendete Session bleiben als gekennzeichnete
  Testdaten erhalten. Bestehende Nutzerworkouts wurden nicht geändert.
- Kein physisches Gerät angeschlossen; Hardwareabnahme steht separat aus.
