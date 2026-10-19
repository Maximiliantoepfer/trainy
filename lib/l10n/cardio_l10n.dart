import 'package:flutter/widgets.dart';
import 'l10n.dart';

extension CardioL10n on BuildContext {
  String cardio(String key) => l10n.cardioText('k_$key');
}
