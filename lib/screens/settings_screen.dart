import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

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
            trailing: DropdownButton<Color>(
              value: accentColor,
              items: [
                DropdownMenuItem(value: myBlue, child: Text('Blau')),
                DropdownMenuItem(value: myRed, child: Text('Rot')),
                DropdownMenuItem(value: myGreen, child: Text('Grün')),
              ],
              onChanged: (color) {
                if (color != null) {
                  themeProvider.setAccentColor(color as MaterialColor);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
