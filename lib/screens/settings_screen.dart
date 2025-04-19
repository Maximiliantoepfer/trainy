import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';

class SettingsScreen extends StatelessWidget {
  // Konstante MaterialColor Objekte für DropdownButton
  static const MaterialColor myBlue = Colors.blue;
  static const MaterialColor myRed = Colors.red;
  static const MaterialColor myGreen = Colors.green;

  @override
  Widget build(BuildContext context) {
    // Zugriff auf ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.getAccentColor();

    return Scaffold(
      appBar: AppBar(title: Text('Einstellungen')),
      body: ListView(
        children: [
          // Wöchentliches Ziel
          Consumer<ProgressProvider>(
            builder: (context, progress, child) {
              return ListTile(
                title: const Text('Wöchentliches Trainingsziel'),
                subtitle: Text('${progress.weeklyGoal}x pro Woche'),
                trailing: DropdownButton<int>(
                  value: progress.weeklyGoal,
                  onChanged: (value) {
                    if (value != null) {
                      progress.setWeeklyGoal(value);
                    }
                  },
                  items:
                      List.generate(7, (i) => i + 1).map((v) {
                        return DropdownMenuItem(value: v, child: Text('$v x'));
                      }).toList(),
                ),
              );
            },
          ),

          // Dark Mode Switch
          ListTile(
            title: Text('Dark Mode'),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeColor: accentColor,
            ),
          ),
          // DropdownButton für Akzentfarbe
          ListTile(
            title: Text('Akzentfarbe'),
            trailing: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            onTap: () => _openColorPicker(context, themeProvider),
          ),
        ],
      ),
    );
  }

  void _openColorPicker(BuildContext context, ThemeProvider themeProvider) {
    Color currentColor = themeProvider.getAccentColor();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Wähle eine Akzentfarbe'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (Color color) {
                currentColor = color;
              },
              enableAlpha: false,
              labelTypes: const [],
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              child: Text('Abbrechen'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Übernehmen'),
              onPressed: () {
                themeProvider.setAccentColor(
                  MaterialColor(currentColor.value, <int, Color>{
                    50: currentColor,
                    100: currentColor,
                    200: currentColor,
                    300: currentColor,
                    400: currentColor,
                    500: currentColor,
                    600: currentColor,
                    700: currentColor,
                    800: currentColor,
                    900: currentColor,
                  }),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
