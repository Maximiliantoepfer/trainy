import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/widgets/app_title.dart';
import '../models/exercise.dart';
import '../providers/exercise_provider.dart';
import '../providers/theme_provider.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final Set<int> _selectedExerciseIds = {};
  bool _isSelectionMode = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          Provider.of<ExerciseProvider>(context, listen: false).loadExercises(),
    );
  }

  void _openExerciseDialog({Exercise? exercise}) {
    final isEditing = exercise != null;
    final nameController = TextEditingController(text: exercise?.name ?? '');
    final descController = TextEditingController(
      text: exercise?.description ?? '',
    );
    final selectedFields = Set<String>.from(exercise?.trackedFields ?? []);
    final defaultValues = Map<String, String>.from(
      exercise?.defaultValues ?? {},
    );
    final defaultUnits = Map<String, String>.from(
      exercise?.units ?? {'Gewicht': 'kg', 'Dauer': 'sec'},
    );
    IconData selectedIcon = exercise?.icon ?? Icons.fitness_center;

    final unitOptions = <String, List<String>>{
      'Sätze': ['x'],
      'Wiederholungen': ['x'],
      'Gewicht': ['kg', 'lbs'],
      'Dauer': ['sec', 'min'],
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void toggleField(String field) {
              if (selectedFields.contains(field)) {
                selectedFields.remove(field);
                defaultValues.remove(field);
                defaultUnits.remove(field);
              } else {
                selectedFields.add(field);
                defaultValues[field] = '';
                defaultUnits[field] = unitOptions[field]?.first ?? '';
              }
              setModalState(() {});
            }

            Widget buildDefaultInput(String label) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2.0,
                  vertical: 1.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Standardwert',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => defaultValues[label] = val,
                        controller: TextEditingController(
                          text: defaultValues[label] ?? '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Einheit',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        value: defaultUnits[label],
                        items:
                            unitOptions[label]!
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null) defaultUnits[label] = val;
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: Text(
                              isEditing
                                  ? 'Übung bearbeiten'
                                  : 'Übung erstellen',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: DropdownButton<IconData>(
                              value: selectedIcon,
                              underline: SizedBox.shrink(),
                              onChanged:
                                  (icon) =>
                                      setModalState(() => selectedIcon = icon!),
                              items:
                                  [
                                        Icons.fitness_center,
                                        Icons.accessibility,
                                        Icons.directions_run,
                                        Icons.self_improvement,
                                        Icons.sports_martial_arts,
                                      ]
                                      .map(
                                        (icon) => DropdownMenuItem(
                                          value: icon,
                                          child: Icon(
                                            icon,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Beschreibung',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Zu trackende Felder:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      for (final field in unitOptions.keys)
                        Column(
                          children: [
                            CheckboxListTile(
                              title: Text(field),
                              value: selectedFields.contains(field),
                              onChanged: (_) => toggleField(field),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (selectedFields.contains(field))
                              buildDefaultInput(field),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Abbrechen'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isEmpty) return;
                              final newExercise = Exercise(
                                id:
                                    exercise?.id ??
                                    DateTime.now().millisecondsSinceEpoch,
                                name: nameController.text,
                                description: descController.text,
                                trackedFields: selectedFields.toList(),
                                defaultValues: Map.from(defaultValues),
                                units: Map.from(defaultUnits),
                                icon: selectedIcon,
                              );
                              await Provider.of<ExerciseProvider>(
                                context,
                                listen: false,
                              ).addOrUpdateExercise(newExercise);
                              Navigator.pop(context);
                            },
                            child: Text(isEditing ? 'Speichern' : 'Erstellen'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Provider.of<ThemeProvider>(context).getAccentColor();

    return Consumer<ExerciseProvider>(
      builder: (context, exerciseProvider, child) {
        final exercises =
            exerciseProvider.exercises.where((e) {
              return e.name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  e.description.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );
            }).toList();

        return Scaffold(
          appBar: AppBar(
            title: AppTitle(
              _isSelectionMode ? 'Übungen auswählen' : 'Übungen',
              emoji: '💪',
            ),

            actions:
                _isSelectionMode
                    ? [
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () async {
                          await Provider.of<ExerciseProvider>(
                            context,
                            listen: false,
                          ).deleteExercises(_selectedExerciseIds.toList());
                          setState(() {
                            _isSelectionMode = false;
                            _selectedExerciseIds.clear();
                          });
                        },
                      ),
                    ]
                    : null,
            bottom:
                !_isSelectionMode
                    ? PreferredSize(
                      preferredSize: Size.fromHeight(56.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Suchen...',
                            border: InputBorder.none,
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                        ),
                      ),
                    )
                    : null,
          ),
          body:
              exerciseProvider.isLoading
                  ? Center(child: CircularProgressIndicator())
                  : exercises.isEmpty
                  ? Center(child: Text('Keine passenden Übungen gefunden.'))
                  : ListView.builder(
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final ex = exercises[index];
                      final isSelected = _selectedExerciseIds.contains(ex.id);
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(ex.icon, color: accentColor, size: 28),
                        ),

                        title: Text(ex.name),
                        subtitle: Text(ex.description),
                        trailing:
                            _isSelectionMode
                                ? Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedExerciseIds.add(ex.id);
                                      } else {
                                        _selectedExerciseIds.remove(ex.id);
                                      }
                                    });
                                  },
                                )
                                : null,
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedExerciseIds.remove(ex.id);
                              } else {
                                _selectedExerciseIds.add(ex.id);
                              }
                            });
                          } else {
                            _openExerciseDialog(exercise: ex);
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedExerciseIds.add(ex.id);
                          });
                        },
                      );
                    },
                  ),
          floatingActionButton:
              !_isSelectionMode
                  ? FloatingActionButton(
                    onPressed: () => _openExerciseDialog(),
                    backgroundColor: accentColor,
                    child: Icon(Icons.add),
                  )
                  : null,
        );
      },
    );
  }
}
