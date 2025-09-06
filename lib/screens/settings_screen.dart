// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/progress_provider.dart'; // nutzt weeklyGoal speichern/lesen

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    final progress = context.watch<ProgressProvider>();
    final weeklyGoal = progress.weeklyGoal.clamp(1, 7); // 1..7

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
          // Darstellung
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
          // Akzentfarbe
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

          // ⬇️ NUR der Block der Farbswatches wird etwas nach rechts eingerückt.
          // Padding wirkt auf den Block, NICHT auf die Abstände zwischen den Items.
          Padding(
            padding: const EdgeInsets.only(
              left: 24,
            ), // Feinjustierbar (z. B. 20–28)
            child: Wrap(
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
          ),

          const SizedBox(height: 12),
          // Ziele
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ziele', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Text(
                    'Trainingstage pro Woche',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1x')),
                      ButtonSegment(value: 2, label: Text('2x')),
                      ButtonSegment(value: 3, label: Text('3x')),
                      ButtonSegment(value: 4, label: Text('4x')),
                      ButtonSegment(value: 5, label: Text('5x')),
                      ButtonSegment(value: 6, label: Text('6x')),
                      ButtonSegment(value: 7, label: Text('7x')),
                    ],
                    selected: {weeklyGoal},
                    onSelectionChanged: (v) {
                      final goal = v.first.clamp(1, 7);
                      context.read<ProgressProvider>().setWeeklyGoal(goal);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _quickSwatches = <Color>[
  Color.fromARGB(255, 59, 111, 255), // blue
  Color.fromARGB(255, 14, 199, 255), // teal
  Color(0xFF00C853), // green
  Color.fromARGB(255, 255, 133, 40), // orange
  Color(0xFFD81B60), // pink
  Color(0xFF9C27B0), // purple
  Color(0xFFF44336), // red
];
