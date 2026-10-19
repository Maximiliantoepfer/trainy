import 'package:flutter/widgets.dart';
import 'l10n.dart';

extension PlanL10n on BuildContext {
  String plan(String key) {
    if (key == 'myPlan') return l10n.trainingPlan;
    final refined = l10n.refinementText('k_$key');
    return refined == 'k_$key' ? l10n.planText('k_$key') : refined;
  }
}
