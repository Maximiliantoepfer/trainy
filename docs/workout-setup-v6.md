# Workout-Einrichtung v6

## Bedienung und Daten

Der Drei-Schritt-Ablauf bleibt erhalten: Grundlagen → Profil → Übungen.
Die sichtbare Bezeichnung ist durchgehend „Profil“ / „Profile“; die unabhängigen
Setup-Inhalte und die Eindeutigkeit je Workout/Profil bleiben unverändert.
Es gibt weder eine Schemaänderung noch einen Datenreset.

- Zielkacheln füllen ein gleichmäßiges 2×2-Raster. Bei schmalen Ansichten oder
  großer Schrift werden daraus einspaltige Auswahlzeilen.
- Beschreibungen haben eine kleine, dauerhaft oben ausgerichtete Beschriftung
  und wachsen von zwei bis vier Zeilen. Außenabstand: 16 dp; Feldabstand: 12 dp.
- „Neues Profil“ verwendet denselben Editor wie die Einstellungen. Nach dem
  lokalen Speichern wird es im Wizard bzw. bestehenden Workout ausgewählt.
- Nur neue Profile starten mit auswählbarem Körpergewicht. Bestehendes Equipment
  wird nicht verändert. Kompakte Chips behalten mindestens 48 dp Touch-Fläche.
- „Neue Übung“ bleibt im gemeinsamen Picker erreichbar. Der Suchtext dient als
  Namensvorschlag. Nach dem Speichern wird bei Mehrfachauswahl die neue Übung
  zusätzlich markiert, ganz oben angezeigt und Suche/Label zurückgesetzt.
  Bei Einzelauswahl wird sie direkt zurückgegeben. Abbrechen verändert nichts.
- Das ausgewählte Profil priorisiert passende Übungen, ohne andere auszublenden.
- Explizit gespeicherte Profile und Übungen bleiben Bibliotheksinhalte, wenn der
  Workout-Wizard anschließend abgebrochen wird.
- Der Home-Leerzustand erhält allein 32 dp zusätzlichen oberen Abstand.

Formulare besitzen und entsorgen ihre Eingaberessourcen selbst. Die äußere
Speicherkoordination wartet auf SQLite. Bei Fehlern bietet ein nicht während des
Schreibens schließbarer Dialog „Erneut versuchen“ / „Abbrechen“; der Entwurf und
bereits erzeugte IDs bleiben für den Retry erhalten. Auch ein bereits verschobenes
Bild wird beim Retry nicht erneut aus dem temporären Pfad gelesen. Das optionale
Cloud-Backup folgt erst nach erfolgreichem lokalen Speichern.

## Unicode und Emulator-Tastatur

Die App beschränkt Namen nicht auf ASCII und ersetzt keine Zeichenfolgen wie
`oe`. Tests prüfen `ÄÖÜäöüß` und ein zerlegtes `O` + kombinierendes Trema nach
SQLite-Schließen und erneutem Laden. Ein Widgettest prüft laufende IME-Komposition.

Read-only-Befund am Pixel_9_Pro (Android API 36, 16.10.2026):

- `hw.keyboard=yes` im AVD.
- Gboard ist die aktive Eingabemethode.
- `dumpsys input` meldet für „AT Translated Set 2 keyboard“ und „qwerty2“
  `KeyboardLayoutInfo: <not set>`; ein ausdrücklich ausgewähltes deutsches
  Hardwarelayout ist damit nicht nachgewiesen.
- Automatisiert über den Desktop eingegebener Unicode-Text erschien im
  Workout-Namensfeld korrekt. Das ist kein Nachweis für die reale Ö-Taste.

Prüfung ohne Wipe oder globale Windows-Änderung:

1. Im Emulator **Android-Einstellungen → System → Tastatur → Physische Tastatur**
   öffnen (je nach Android-Version ähnlich benannt). Die erkannte Tastatur
   wählen und **Deutsch / QWERTZ** passend zur tatsächlich verwendeten
   PC-Tastatur einstellen. Nicht nur die Gboard-Bildschirmtastatur umstellen.
2. Den Eingabefokus in Trainys Namensfeld setzen, nicht in den IDE-Editor.
   `ÄÖÜäöüß` und `Z/Y` mit echten Tasten vergleichen.
3. Denselben Text über die deutsche Gboard-Bildschirmtastatur eingeben. Geht
   nur diese Variante, liegt der Unterschied vor der Flutter-Texteingabe.
4. Falls die eingebettete IDE-Weiterleitung weiter abweicht: den vorhandenen
   Emulator in einem separaten Fenster testen. Keinen zweiten Prozess mit
   derselben AVD starten und keine Emulator-Daten löschen.

Die physische Tastenbelegung ist noch vom Nutzer mit seiner tatsächlichen
PC-Tastatur abzugleichen. Es wurden keine Windows- oder AVD-Einstellungen geändert.
Grundlagen: [Android-Emulator-Eingabe](https://developer.android.com/studio/run/emulator#navigate),
[physische Tastaturlayouts](https://support.google.com/android/answer/14114879),
[Gboard-Sprachen](https://support.google.com/gboard/answer/7068494).

## Regressionen und Abnahme

```powershell
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --debug
```

`test/workout_setup_v6_test.dart` prüft Rasterbreite, Beschreibung, Unicode/IME,
direkte Profilerstellung samt automatischer Auswahl und Eindeutigkeit,
Bodyweight-Default, unveränderte Altprofile, Abbruch, Fehler/Retry,
Übungsneuanlage mit Einfach-/Mehrfachauswahl, schmale Ansichten mit zweifacher
Schrift und Tastatur sowie den isolierten Home-Abstand. Die neuen Goldens
verwenden die mit Flutter gebündelte Roboto-Schrift statt des Ahem-Testfonts.

`test/workout_setup_v6_storage_test.dart` prüft die unveränderten Namen von
Workouts, Profilen und Übungen über die echten SQLite-Speicherpfade und einen
geschlossenen/erneut geöffneten Datenbank-Handle.

Visuell im laufenden Pixel-9-Pro-Emulator geprüft: Zielraster, Unicode im
Workout-Namen, direkte Profilmaske mit kompakter Equipmentauswahl,
vorausgewähltem Körpergewicht sowie Übungspicker und Erstellungsformular.
Für diese UI-Prüfung werden keine bestehenden Trainingsdaten verändert.
Der reale PC-Tastenvergleich bleibt eine separate manuelle Abnahme.

Abschlussstand: `flutter gen-l10n`, `flutter analyze`, alle 75 Tests und
`flutter build apk --debug` erfolgreich. Die manuellen Dialogprüfungen wurden
abgebrochen, ohne QA-Profile, Übungen oder Workouts in der Nutzerbibliothek zu
hinterlassen; Speicher- und Retry-Abläufe sind automatisiert geprüft.
