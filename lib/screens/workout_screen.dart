import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/providers/theme_provider.dart';
import 'package:trainy/utils/utils.dart';
import '../models/workout.dart';

class WorkoutScreen extends StatefulWidget {
  // Verwende StatefulWidget
  final Workout workout;

  WorkoutScreen({required this.workout});

  @override
  _WorkoutScreenState createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late TextEditingController _nameController;
  bool _isEditing = false; // Variable, um den Bearbeitungszustand zu verfolgen

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            setState(() {
              _isEditing = true; // Bearbeitungsmodus aktivieren
            });
          },
          child:
              _isEditing
                  ? TextField(
                    controller: _nameController,
                    style: TextStyle(color: getTextColor(context)),
                    onChanged: (value) {
                      // Hier kannst du den Workout-Namen aktualisieren
                      // (z.B. in einer Datenbank oder im State Management)
                    },
                    onEditingComplete: () {
                      setState(() {
                        _isEditing = false; // Bearbeitungsmodus deaktivieren
                      });
                    },
                  )
                  : Text(
                    widget.workout.name,
                    style: TextStyle(color: getTextColor(context)),
                  ),
        ),
      ),
      body: Center(
        child: Text(
          'Übungen für ${widget.workout.name} werden hier angezeigt.',
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Funktion zum Hinzufügen einer Übung
          _addExercise();
        },
        child: Icon(Icons.add),
        backgroundColor: Provider.of<ThemeProvider>(context).getAccentColor(),
      ),
    );
  }

  void _addExercise() {
    // Hier kannst du ein Dialogfenster oder einen neuen Bildschirm anzeigen,
    // um eine neue Übung hinzuzufügen.
    // Für den Anfang zeigen wir einen einfachen Dialog an.
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Neue Übung hinzufügen'),
          content: Text('Hier kannst du später eine neue Übung hinzufügen.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Schließen'),
            ),
          ],
        );
      },
    );
  }
}
