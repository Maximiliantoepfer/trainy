// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/workout_provider.dart';
import '../providers/progress_provider.dart'; // ⬅️ NEU: für Wochen-Widget
import '../widgets/workout_card.dart';
import 'workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedWorkoutId;

  @override
  void initState() {
    super.initState();
    // Beim ersten Öffnen Workouts + Progress laden
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Workouts
      context.read<WorkoutProvider>().loadWorkouts();
      // ⬅️ NEU: Progress (Einträge für Wochen-Widget)
      // (falls der Provider nicht im Tree ist, wirft das -> in deinem Setup ist er vorhanden)
      context.read<ProgressProvider>().loadData();
    });
  }

  Future<void> _createWorkout(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final provider = context.read<WorkoutProvider>();

    String? name = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Neues Workout'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Workout-Namen eingeben',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Bitte Namen eingeben';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(ctx).pop(controller.text.trim());
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(ctx).pop(controller.text.trim());
                  }
                },
                child: const Text('Speichern'),
              ),
            ],
          ),
    );

    if (name == null) return;

    final w = await provider.createWorkout(name: name);
    if (!mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WorkoutScreen(workout: w)));
    await provider.loadWorkouts();
  }

  Future<void> _confirmAndDelete(Workout workout) async {
    final provider = context.read<WorkoutProvider>();
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Workout löschen?'),
            content: Text(
              '„${workout.name}“ wird endgültig gelöscht. Fortfahren?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
                  foregroundColor: MaterialStateProperty.all<Color>(
                    Colors.white,
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Löschen'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    await provider.deleteWorkout(workout.id);
    if (!mounted) return;

    setState(() => _selectedWorkoutId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('„${workout.name}“ gelöscht'),
        backgroundColor: scheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openWorkout(Workout workout) async {
    if (_selectedWorkoutId != null) {
      // Wenn Auswahl aktiv: erst Auswahl aufheben statt navigieren
      setState(() => _selectedWorkoutId = null);
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WorkoutScreen(workout: workout)));
    if (!mounted) return;
    await context.read<WorkoutProvider>().loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final workouts = provider.workouts;

    // ⬅️ NEU: Progress lesen und Trainings-Tage der aktuellen Woche berechnen
    final progress = context.watch<ProgressProvider>();
    final trainedWeekdays = _trainedWeekdaysThisWeek(progress.entries);
    final isProgressLoading = progress.isLoading;

    return WillPopScope(
      onWillPop: () async {
        if (_selectedWorkoutId != null) {
          setState(() => _selectedWorkoutId = null);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workouts'),
          actions: [
            IconButton(
              onPressed: () => _createWorkout(context),
              icon: const Icon(Icons.add),
              tooltip: 'Neues Workout',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createWorkout(context),
          child: const Icon(Icons.add),
        ),
        body:
            provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // ⬅️ NEU: Wochen-Widget oberhalb der Liste
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _WeeklyOverviewCard(
                        trainedWeekdays:
                            isProgressLoading
                                ? const {} // solange Progress lädt → neutral anzeigen
                                : trainedWeekdays,
                      ),
                    ),
                    // Liste / EmptyState
                    Expanded(
                      child:
                          workouts.isEmpty
                              ? const _EmptyState()
                              : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  100,
                                ),
                                itemCount: workouts.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, i) {
                                  final w = workouts[i];
                                  final selected = w.id == _selectedWorkoutId;

                                  return WorkoutCard(
                                    workout: w,
                                    selected: selected,
                                    onTap: () => _openWorkout(w),
                                    onLongPress: () {
                                      setState(
                                        () =>
                                            _selectedWorkoutId =
                                                selected ? null : w.id,
                                      );
                                    },
                                    onPrimaryActionTap: () {
                                      if (selected) {
                                        _confirmAndDelete(w);
                                      } else {
                                        _openWorkout(w);
                                      }
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
    );
  }

  /// Berechnet die (Mo=1..So=7) Wochentage der **aktuellen** Woche, an denen trainiert wurde
  /// – unabhängig davon, welches Workout es war.
  Set<int> _trainedWeekdaysThisWeek(List entries) {
    if (entries.isEmpty) return {};
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1)); // Mo als Wochenstart
    final start = DateTime(monday.year, monday.month, monday.day);
    final endExclusive = start.add(const Duration(days: 7));

    final set = <int>{};
    // entries ist List<WorkoutEntry>, aber um nicht zu import-lastig zu werden, dynamisch:
    for (final e in entries) {
      final DateTime d = e.date;
      if (!d.isBefore(start) && d.isBefore(endExclusive)) {
        set.add(d.weekday); // 1..7
      }
    }
    return set;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 52),
            const SizedBox(height: 16),
            Text('Noch keine Workouts', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Erstelle dein erstes Workout mit dem Plus-Button.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// --- NEU: Modernes Wochen-Widget (Mo–So) ------------------------------------

class _WeeklyOverviewCard extends StatelessWidget {
  final Set<int> trainedWeekdays; // 1=Mo .. 7=So
  const _WeeklyOverviewCard({required this.trainedWeekdays});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titelzeile
            Row(
              children: [
                Text('Diese Woche', style: text.titleMedium),
                const Spacer(),
                // Kleine Fortschrittsanzeige z. B. "3/7"
                Text(
                  '${trainedWeekdays.length}/7',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 7 gleichmäßig verteilte „Pills“ mit Tages-Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final weekday = i + 1; // 1..7
                final done = trainedWeekdays.contains(weekday);
                final label = labels[i];
                return _DayPill(label: label, done: done);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final String label;
  final bool done;
  const _DayPill({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Neutrale Variante (nicht trainiert): dezente Fläche + Outline + Label darunter
    // Done-Variante: sattes Grün, weißer Check, Label bleibt neutral unten.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: done ? const Color(0xFF2E7D32) : scheme.surfaceVariant,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? const Color(0xFF2E7D32) : scheme.outlineVariant,
            ),
            boxShadow:
                done
                    ? const [
                      BoxShadow(
                        color: Color(0x402E7D32),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child:
                done
                    ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('icon_done'),
                      color: Colors.white,
                      size: 20,
                    )
                    : Icon(
                      Icons.fiber_manual_record,
                      // kleiner „Dot“ als neutraler Placeholder
                      key: const ValueKey('icon_neutral'),
                      size: 10,
                      color: scheme.onSurfaceVariant,
                    ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
