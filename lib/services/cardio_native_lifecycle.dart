import 'dart:convert';
import 'dart:io';
import 'generated/cardio_api.g.dart';

abstract final class CardioNativeLifecycle {
  static bool get supported => Platform.isAndroid || Platform.isIOS;
  static Future<void> ensureRestoreAllowed() async {
    if (!supported) return;
    final state = await CardioHostApi().state();
    if (state != null) {
      throw StateError(
        (jsonDecode(state) as Map)['status'] == 'completed'
            ? 'Finish saving the completed workout before restoring.'
            : 'Finish the active workout before restoring.',
      );
    }
  }

  static Future<void> discard() async {
    if (supported) await CardioHostApi().discard();
  }
}
