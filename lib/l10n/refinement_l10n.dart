import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';

extension RefinementL10n on BuildContext {
  String refine(String key) =>
      AppLocalizations.of(this)!.refinementText('k_$key');
}
