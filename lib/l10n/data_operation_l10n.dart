import 'package:flutter/widgets.dart';
import '../services/data_operation.dart';

String dataOperationMessage(BuildContext context, Object error) {
  final failure = DataOperationFailure.from('local', error);
  final de = Localizations.localeOf(context).languageCode == 'de';
  final message = switch (failure.code) {
    'operation-in-progress' =>
      de
          ? 'Eine Datenaktion läuft bereits. Bitte warte kurz.'
          : 'A data operation is already running. Please wait.',
    'unauthenticated' || 'requires-recent-login' || 'user-token-expired' =>
      de
          ? 'Bitte melde dich erneut an und wiederhole die Aktion.'
          : 'Please sign in again and retry.',
    'user-mismatch' =>
      de
          ? 'Bitte bestätige das aktuell angemeldete Google-Konto.'
          : 'Please confirm the Google account currently signed in.',
    'cancelled' || 'sign_in_canceled' =>
      de
          ? 'Bestätigung abgebrochen. Es wurde nichts gelöscht.'
          : 'Confirmation cancelled. Nothing was deleted.',
    'unauthorized' || 'permission-denied' =>
      de
          ? 'Keine Berechtigung für die Cloud-Daten. Bitte erneut anmelden; falls es bestehen bleibt, den Fehlercode melden.'
          : 'Cloud access was denied. Sign in again; if it persists, report the error code.',
    'network-request-failed' || 'retry-limit-exceeded' || 'timeout' =>
      de
          ? 'Die Verbindung ist unterbrochen. Bitte erneut versuchen; bereits erledigte Schritte werden berücksichtigt.'
          : 'The connection was interrupted. Please retry; completed steps are retained.',
    _ =>
      de
          ? 'Die Aktion konnte nicht abgeschlossen werden. Bitte erneut versuchen und bei wiederholtem Fehler diesen Code melden.'
          : 'The operation could not finish. Please retry and report this code if it persists.',
  };
  return '$message (${failure.stage}/${failure.code})';
}
