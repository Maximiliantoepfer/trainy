# Workout-Flow v7

## Bedienung

- Der dreistufige Wizard bleibt erhalten. Ab Schritt 2 steht der eingegebene
  Workout-Name in der App-Bar. Schritt 3 zeigt die gewählten Übungen mit lokalem
  Cover, direktem Entfernen und Ziehgriff in ihrer tatsächlichen Reihenfolge.
- Die Mehrfachauswahl bestätigt unten mit **Übernehmen (Anzahl)**. Auch null
  ausgewählte Übungen sind übernehmbar. **Neue Übung** ist eine sekundäre
  Aktion oben; bei schmalen Ansichten/großer Schrift erhält sie eine eigene
  Zeile. Einzelauswahl im Training bleibt unmittelbar.
- Katalog- und eigene Übungen behalten eine gemeinsame Auswahlreihenfolge.
  Bereits materialisierte Katalogübungen erscheinen nur einmal. Abbruch ändert
  weder die vorherige Auswahl noch deren Reihenfolge.
- Im Workout öffnet eine einzige Profilzeile die Auswahl. Der zusätzliche
  Plusbutton entfällt. Ein altes profilfreies Standard-Setup zeigt außen
  **Profil auswählen**; individuelle alte Setup-Namen bleiben sichtbar.
- Bereits eingerichtete Profile wechseln direkt zu ihren unabhängigen Inhalten.
  Für ein neues Workout-Profil wird **Übungen übernehmen** oder **Leer beginnen**
  angeboten. Ein altes profilfreies Setup kann ausdrücklich mit einem Profil
  verbunden werden. Pro Workout bleibt höchstens eine Bindung je konkretem Profil.
- **Mit … starten** startet das sichtbare Profil ohne zweite Auswahl. Leere
  Workouts können gespeichert werden; beim Start wird zunächst auf fehlende
  Übungen hingewiesen. Eine schon laufende Session wird nicht überschrieben.

## Profile und Onboarding

Neue Workouts benötigen ein aktives Profil. Bestehende profilfreie Workouts,
archivierte Profilbindungen und historische Sessions bleiben lesbar und startbar.
Es findet keine automatische Zuordnung alter Workouts statt.

Neue Installationen richten nach dem weiterhin optionalen Cloud-Schritt zwei
editierbare Vorlagen ein:

- **Home Gym:** zunächst Körpergewicht, weiterhin abwählbar.
- **Gym:** die unterstützte typische Studioausstattung, ohne Fahrrad,
  Schwimmbecken und Sonstiges. Individuelle Änderungen sind ausdrücklich möglich.

Der ausgewählte Standard wird nur für **neue** Workouts vorgeschlagen. Er ändert
weder bestehende Setups noch den unabhängigen Bibliotheksfilter. Weitere Profile
sind weiterhin beliebig anlegbar. Im Profileditor gibt es Home Gym/Gym/Individuell,
**Alle auswählen**, **Auswahl aufheben** und eine Anzahl ausgewählter Geräte.
Das Bearbeiten bestehender Profile wendet nie ungefragt eine Vorlage an.

Bestandsnutzer erhalten einen einmaligen optionalen Einrichtungshinweis. Gleich
benannte vorhandene Profile müssen ausdrücklich wiederverwendet oder die neuen
Vorlagen umbenannt werden; vorhandenes Equipment wird nicht überschrieben.
Das Onboarding speichert beide Vorlagen, Standard und Abschlussstatus atomar.
Ein Retry verwendet dieselben IDs.

## Daten und technische Entscheidungen

- Datenepoch **2** bleibt unverändert. Schema **5 → 6** ergänzt ausschließlich
  `user_settings.profile_setup_state` mit `required`, `offer`, `dismissed`,
  `completed`. Neue Datenbanken starten mit `required`, Upgrades mit `offer`.
- `selected_training_profile` wird als bevorzugtes Profil für neue Workouts
  wiederverwendet. Es entsteht weder ein zweites Profilsystem noch ein Reset.
- `TrainingProfileProvider` veröffentlicht lokale Änderungen an alle Screens.
  Die zuvor unabhängigen Ansichten von Wizard, Details, Einstellungen und
  Bibliothek werden nach Änderungen aktualisiert. Fehler bieten Retry.
- Der konkrete Verknüpfungsfehler war `INSERT OR REPLACE`: SQLite löscht damit
  den bisherigen Profildatensatz und konnte durch `ON DELETE SET NULL` bestehende
  Setup-/Gruppen-/Session-Verknüpfungen lösen. Speichern aktualisiert nun in
  einer Transaktion die vorhandene Zeile; nur neue IDs werden eingefügt.
  Bereits früher gelöste Verknüpfungen werden nicht geraten oder automatisch
  rückwirkend verändert. Sie können im Workout ausdrücklich verbunden werden.
- Neue Workout- und Setup-Entwürfe haben stabile IDs. Wiederholungen nach einem
  bereits erfolgreichen Schreibvorgang erzeugen keine zweite Anlage.
- Schema-4- und Schema-5-ZIP-Backups werden isoliert validiert und in Schema 6
  überführt. Ungültige Fremdschlüssel verhindern den Austausch aktiver Daten.
- Alle neuen Abläufe bleiben lokal. Cloud-Anmeldung, Netzwerk und Runtime-
  Medien-Downloads sind dafür nicht notwendig.

## Bibliothek und Wochenplan

Der Filterzähler verwendet `ColorScheme.primary/onPrimary`, nicht die Fehlerfarbe.
Das Symbol ist `filter_list_rounded`. **Dubletten prüfen** ist nur bei offenen
Vorschlägen sichtbar; ein Prüfungsfehler erhält einen separaten Retry.

Die Dublettenprüfung verwendet den gültigen Konfidenzwert `high` statt des früher
vom Datenbank-Constraint abgewiesenen Werts. Sie entfernt veraltete/offen doppelte
Vorschläge, respektiert akzeptierte und verworfene Entscheidungen und führt keine
automatischen Zusammenführungen durch. Auch Übungen werden deshalb nun in-place
aktualisiert, damit das Bearbeiten keine FK-gebundenen Entscheidungen löscht.

Leere Wochentage sind kompakte Zeilen ohne sieben wiederholte Leertexte. Belegte
Tage behalten Ziel-Icon, Namen, sofortigen Ziehgriff und Papierkorb. Ziehen kann
am Bildschirmrand scrollen. Rückgängig stellt Tag und Position wieder her.
Eine fehlgeschlagene Aktualisierung wiederholt keine bereits gespeicherte Löschung.
Screenreader erhalten zusätzliche Verschiebeaktionen; reduzierte Bewegung wird
respektiert. Der Plan bleibt eine wiederkehrende Wochenvorlage ohne Kalenderdatum.

## Prüfung

```powershell
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --debug
```

Neue Regressionen:

- `workout_flow_v7_repository_test.dart`: aktive Profile, FK-Erhalt einschließlich
  historischer Sessions, stabile IDs, unabhängige Kopien/leere Profile, explizite
  Altbindung, atomarer Onboarding-Rollback, gemeinsamer Profilzustand, Schema-Upgrade.
- `workout_flow_v7_duplicates_test.dart`: gültige Vorschläge, idempotente Prüfung,
  akzeptierte/verworfene Entscheidungen über Bearbeitungen hinweg, veraltete Treffer.
- `workout_flow_v7_widget_test.dart`: sichtbare gemischte Übungsauswahl und Reihenfolge,
  Footer und Nullauswahl, Onboarding-Retry, sofortige Aktualisierung der Einstellungen,
  direkter Start, Wochenplan-Drag/Undo/Retry und Akzentfarbe des Filterzählers.
- Bestehende v5/v6-Tests behalten Unicode/IME, schmale Ansichten, zweifache Schrift,
  offene Tastatur, Dark/Light Mode, eigenes Equipment und Session-Wiederaufnahme.
- Backup-Tests prüfen jetzt sowohl Schema 4 als auch Schema 5 gegen Schema 6.
- Neue Screenshot-Referenzen sichern Wizard-Auswahl, Picker, Onboarding und Planer;
  Bilder werden vor dem Vergleich vollständig lokal dekodiert.

### Android-Abnahme

Automatischer Abschlussstand am 19.10.2026: `flutter gen-l10n`,
`flutter analyze` (keine Befunde), **91 Tests** und Debug-APK erfolgreich.

Eine Debug-APK wird unter `build/app/outputs/flutter-apk/app-debug.apk` erzeugt.
Am 19.10.2026 war nur `emulator-5554` angeschlossen, kein physisches Gerät.
Nach ausdrücklicher Freigabe wurden die Appdaten des AVD **Pixel_9_Pro** bei
beendeter App lokal gesichert: `databases`, `shared_prefs` und `app_flutter`.
Das lesbare TAR-Archiv liegt ausschließlich unter
`.tmp/v7-qa/before-update-20261019.tar` (69.931.008 Bytes, Git-ignoriert).
Es wurde weder eingecheckt noch hochgeladen. SHA-256:
`DD9D8A8E69F7A215FECC860FD3424DAD6D7385365B8D19CA3776743A7D6397F7`.

Das Update über `tool/verify_android_launch.ps1 -SkipBuild` mit `adb install -r`
war erfolgreich; der Android-Starttest bestand. Die Datenbank verwendet Schema 6,
`integrity_check` meldet `ok`, `foreign_key_check` keine Verletzungen.
Vorhandene Spalten und Zeilen von **54 Datentabellen** wurden unmittelbar nach der
Migration und erneut nach dem manuellen Durchlauf bidirektional verglichen:
keine Unterschiede. `app_meta` und neue Schemafelder sind von diesem Vergleich
ausgenommen. Bestehende Workouts, Profile und Trainingsdaten blieben erhalten.

Manuell auf dem Emulator geprüft:

- Optionalen Einrichtungshinweis und Home-Gym-/Gym-Vorschau geöffnet, ohne
  Vorlagen zu speichern oder vorhandenes Equipment zu überschreiben. Der
  einmalige Hinweis wurde dabei erwartungsgemäß als gesehen vermerkt.
- Wizard: Workout-Name ab Schritt 2, vorhandenes Gym-Profil, zwei ausgewählte
  Katalogübungen mit Bildern, unterer Übernehmen-Button und sofortiges Umsortieren
  am Ziehgriff. Der ungespeicherte Testentwurf wurde anschließend verworfen.
- Vollständige lokale Übungsauswahl auch ohne aktive Netzwerkverbindung geöffnet;
  WLAN und mobile Daten danach auf ihren ursprünglichen aktiven Zustand gesetzt.
- Dasselbe vorhandene Gym-Profil einschließlich seiner 18 ausgewählten
  Equipmentwerte in den Einstellungen sichtbar; kompakte leere Wochenplanzeilen
  visuell geprüft. Die App bleibt anschließend auf der Startseite geöffnet.
- Im Log des aktuellen App-Prozesses keine Signaturen für Absturz, unbehandelte
  Exception, Layout-Overflow oder SQLite-Fehler gefunden.

Es wurden keine Testprofile, Übungen, Workouts oder Sessions dauerhaft angelegt.
Noch offen bleiben die folgenden vollständigen, schreibenden Abläufe auf Android
sowie die Abnahme auf einem physischen Gerät; automatisierte Tests ersetzen diese
manuellen Prüfungen nicht:

1. Optionalen Bestandsnutzer-Hinweis oder frisches Onboarding, Profilvorlagen und
   bevorzugtes Profil vollständig speichern; keine Pflicht-Cloud-Anmeldung.
2. Workout benennen, Profil auswählen, eigene/Katalogübungen mischen, sortieren,
   speichern und erneut öffnen; Name und Reihenfolge müssen unverändert sein.
3. Zweites Profil mit Kopie und danach Änderungen nur darin; vorhandenes Profil
   direkt umschalten und ohne weitere Auswahl starten.
4. Profil im Workout bearbeiten, anschließend Einstellungen öffnen: derselbe
   Name/dasselbe Equipment und unveränderte Workout-Bindungen.
5. Wochenplan zwischen und innerhalb der Tage ziehen, löschen und rückgängig;
   Bibliotheksfilter und Dublettensichtbarkeit kontrollieren.
6. Offline sowie DE/EN, Light/Dark, eigene Akzentfarbe und große Schrift prüfen.

Kein Push. Vorhandene reine Zeilenende-Änderungen der generierten
Desktop-Registranten bleiben unstaged.
