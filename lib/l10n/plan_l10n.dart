import 'package:flutter/widgets.dart';
import 'l10n.dart';

extension PlanL10n on BuildContext {
  String plan(String key) => l10n.planText('k_$key');
}
