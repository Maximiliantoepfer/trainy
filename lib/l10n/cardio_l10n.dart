import 'package:flutter/widgets.dart';
import 'l10n.dart';

extension CardioL10n on BuildContext {
  String cardio(String key) =>
      ['notFaster', 'notSlower'].contains(key)
          ? l10n.refinementText('k_$key')
          : l10n.cardioText('k_$key');
}
