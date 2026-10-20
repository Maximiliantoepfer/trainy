import 'data_operation.dart';

/// Ordered, restartable account deletion. Each remote operation must tolerate
/// an already empty account. The journal is cleared only by successful reset.
abstract final class AccountDeletion {
  static Future<void> run({
    required Future<void> Function() reauthenticate,
    required Future<void> Function() stopBackup,
    required Future<void> Function(String) journal,
    required Future<void> Function() deleteCloud,
    required Future<void> Function() deleteAuth,
    required Future<void> Function() deleteLocal,
  }) async {
    await DataOperation.step('reauthenticate', reauthenticate);
    await stopBackup();
    await journal('cloud');
    await DataOperation.step('cloud-delete', deleteCloud);
    await journal('auth');
    await DataOperation.step('account-delete', deleteAuth);
    await journal('authDeleted');
    await DataOperation.step('local-delete', deleteLocal);
  }
}
