import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../l10n/l10n.dart';

class AppearancePicker extends StatelessWidget {
  const AppearancePicker({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<ThemeProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in ThemeMode.values)
              ChoiceChip(
                label: Text(switch (mode) {
                  ThemeMode.system => context.l10n.system,
                  ThemeMode.light => context.l10n.light,
                  ThemeMode.dark => context.l10n.dark,
                }),
                selected: p.themeMode == mode,
                onSelected: (_) => p.setThemeMode(mode),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.accentColor,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final color in const [
              Color(0xFF5285FA),
              Color(0xFF0EC7FF),
              Color(0xFF4CAF50),
              Color(0xFFFF5722),
              Color(0xFFD32F2F),
              Color(0xFFE91E63),
            ])
              Semantics(
                label:
                    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                selected: color == p.accent,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => p.setAccent(color),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child:
                        color == p.accent
                            ? Icon(
                              Icons.check,
                              color:
                                  color.computeLuminance() > .179
                                      ? Colors.black
                                      : Colors.white,
                            )
                            : null,
                  ),
                ),
              ),
            IconButton.filledTonal(
              tooltip: context.l10n.accentColor,
              icon: const Icon(Icons.palette_outlined),
              onPressed: () async {
                var color = p.accent;
                final result = await showDialog<Color>(
                  context: context,
                  builder:
                      (c) => AlertDialog(
                        title: Text(c.l10n.accentColor),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: color,
                            onColorChanged: (v) => color = v,
                            enableAlpha: false,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(c.l10n.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, color),
                            child: Text(c.l10n.save),
                          ),
                        ],
                      ),
                );
                if (result != null) await p.setAccent(result);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Trainy',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: .65),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Trainy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
