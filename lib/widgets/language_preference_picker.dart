import 'package:flutter/material.dart';

import '../providers/locale_provider.dart';

/// Keeps language options deliberately short and language-neutral. The
/// dropdown fallback avoids overflow for accessibility text scaling.
class LanguagePreferencePicker extends StatelessWidget {
  const LanguagePreferencePicker({
    super.key,
    required this.preference,
    required this.onChanged,
    this.showAllOptions = false,
  });

  final AppLanguagePreference preference;
  final ValueChanged<AppLanguagePreference> onChanged;

  /// Onboarding keeps every language visible, including on narrow screens.
  final bool showAllOptions;

  static const _values = <AppLanguagePreference>[
    AppLanguagePreference.system,
    AppLanguagePreference.german,
    AppLanguagePreference.english,
  ];

  String _label(AppLanguagePreference value) => switch (value) {
    AppLanguagePreference.system => 'System',
    AppLanguagePreference.german => 'Deutsch',
    AppLanguagePreference.english => 'English',
  };

  @override
  Widget build(BuildContext context) {
    if (showAllOptions) {
      return Column(
        children: [
          for (final value in _values)
            Card(
              child: RadioListTile<AppLanguagePreference>(
                value: value,
                groupValue: preference,
                title: Text(_label(value)),
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledText = MediaQuery.textScalerOf(context).scale(14);
        final useDropdown = constraints.maxWidth < 360 || scaledText > 17;
        if (useDropdown) {
          return DropdownButtonFormField<AppLanguagePreference>(
            value: preference,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items:
                _values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          _label(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          );
        }
        return SegmentedButton<AppLanguagePreference>(
          showSelectedIcon: false,
          segments:
              _values
                  .map(
                    (value) => ButtonSegment(
                      value: value,
                      label: Text(
                        _label(value),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  )
                  .toList(),
          selected: {preference},
          onSelectionChanged: (values) => onChanged(values.first),
        );
      },
    );
  }
}
