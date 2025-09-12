import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../widgets/active_workout_banner.dart';
import '../providers/cloud_sync_provider.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ExerciseProvider>().loadExercises());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();
    final list = provider.exercises;
    final filtered = _query.isEmpty
        ? list
        : list
            .where((e) {
              final q = _query.toLowerCase();
              return e.name.toLowerCase().contains(q) ||
                  (e.description?.toLowerCase().contains(q) ?? false);
            })
            .toList();

    final isActive = context.watch<ActiveWorkoutProvider>().isActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Übungen'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight((isActive ? 56 : 0) + 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive) const ActiveWorkoutBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Übungen durchsuchen',
                  leading: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: 'Leeren',
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _query = '';
                            _searchCtrl.clear();
                          });
                        },
                      ),
                  ],
                  onChanged: (v) => setState(() => _query = v),
                  elevation: const MaterialStatePropertyAll(0),
                  padding: const MaterialStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  backgroundColor: MaterialStatePropertyAll(
                    Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? _EmptyState(onAdd: () => _openEditor(context))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final e = filtered[i];
                    return Card(
                      child: ListTile(
                        title: Text(
                          e.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (e.trackSets) 'Sätze',
                            if (e.trackReps) 'Wdh.',
                            if (e.trackWeight) 'Gewicht',
                            if (e.trackDuration) 'Dauer',
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openEditor(context, existing: e),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Neu'),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {Exercise? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    bool trackSets = existing?.trackSets ?? true;
    bool trackReps = existing?.trackReps ?? true;
    bool trackWeight = existing?.trackWeight ?? true;
    bool trackDuration = existing?.trackDuration ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          existing == null
                              ? 'Übung erstellen'
                              : 'Übung bearbeiten',
                          style: Theme.of(ctx).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Name *',
                              hintText: 'z. B. Plank',
                            ),
                            autofocus: true,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: descCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Beschreibung',
                            ),
                            minLines: 1,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Column(
                              children: [
                                SwitchListTile(
                                  value: trackSets,
                                  onChanged: (v) => setModal(() => trackSets = v),
                                  title: const Text('Sätze'),
                                  subtitle: const Text('z. B. 3 Sätze'),
                                ),
                                SwitchListTile(
                                  value: trackReps,
                                  onChanged: (v) => setModal(() => trackReps = v),
                                  title: const Text('Wiederholungen'),
                                  subtitle: const Text('z. B. 10 pro Satz'),
                                ),
                                SwitchListTile(
                                  value: trackWeight,
                                  onChanged: (v) => setModal(() => trackWeight = v),
                                  title: const Text('Gewicht'),
                                  subtitle: const Text('z. B. 50 kg'),
                                ),
                                SwitchListTile(
                                  value: trackDuration,
                                  onChanged: (v) => setModal(() => trackDuration = v),
                                  title: const Text('Dauer'),
                                  subtitle: const Text('z. B. 60 Sekunden'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;

                              final provider = ctx.read<ExerciseProvider>();
                              await provider.addOrUpdateExercise(
                                id: existing?.id,
                                name: name,
                                description: descCtrl.text.trim(),
                                trackSets: trackSets,
                                trackReps: trackReps,
                                trackWeight: trackWeight,
                                trackDuration: trackDuration,
                              );
                              // trigger cloud backup soon (debounced)
                              try {
                                ctx.read<CloudSyncProvider>().scheduleBackupSoon();
                              } catch (_) {}

                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      existing == null
                                          ? 'Übung "$name" angelegt'
                                          : 'Übung "$name" aktualisiert',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: Text(existing == null ? 'Erstellen' : 'Speichern'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Übungen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Lege deine erste Übung an, um zu starten.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Übung anlegen'),
            ),
          ],
        ),
      ),
    );
  }
}
