import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'providers/theme_provider.dart';
import 'screens/main_navigation.dart';

void main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // final dbPath = await getDatabasesPath();
  // await deleteDatabase(join(dbPath, 'trainy.db'));
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      // Verwende Consumer
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'trainy',
          theme: themeProvider.getTheme().copyWith(
            // Verwende copyWith
            colorScheme: themeProvider.getTheme().colorScheme.copyWith(
              primary: themeProvider.getAccentColor(),
            ),
          ),
          home: MainNavigation(),
        );
      },
    );
  }
}
