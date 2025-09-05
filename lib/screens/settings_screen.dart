import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;

    Future<void> _pickAccent() async {
      Color temp = theme.accent;
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Akzentfarbe wählen'),
              content: SingleChildScrollView(
                child: BlockPicker(
                  pickerColor: temp,
                  onColorChanged: (c) => temp = c,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    theme.setAccent(temp);
                  },
                  child: const Text('Übernehmen'),
                ),
              ],
            ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Darstellung',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.auto_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Hell'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dunkel'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {theme.themeMode},
                    onSelectionChanged: (v) => theme.setThemeMode(v.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Akzentfarbe'),
              subtitle: const Text('Gilt global für UI-Elemente'),
              leading: CircleAvatar(backgroundColor: theme.accent),
              trailing: FilledButton.tonalIcon(
                onPressed: _pickAccent,
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Ändern'),
              ),
              onTap: _pickAccent,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _quickSwatches)
                InkWell(
                  onTap: () => theme.setAccent(c),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            c == theme.accent
                                ? scheme.primary
                                : scheme.outlineVariant,
                        width: c == theme.accent ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const _quickSwatches = <Color>[
  Color.fromARGB(255, 59, 109, 246), // blue
  Color(0xFF0092BF), // teal
  Color(0xFF00C853), // green
  Color.fromARGB(255, 255, 133, 40), // orange
  Color(0xFFD81B60), // pink
  Color(0xFF9C27B0), // purple
  Color(0xFFF44336), // red
];
