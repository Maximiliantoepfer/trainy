import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/exercise_provider.dart';
import '../models/exercise.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();
    final items = provider.exercises;

    return Scaffold(
      appBar: AppBar(title: const Text('Übungen')),
      body:
          items.isEmpty
              ? const Center(child: Text('Noch keine Übungen angelegt'))
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final e = items[i];
                  return Card(
                    child: ListTile(
                      title: Text(e.name),
                      subtitle:
                          e.trackedFields.isNotEmpty
                              ? Text(e.trackedFields.join(' · '))
                              : null,
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Dialog/Screen zum Hinzufügen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Exercise – noch implementieren')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
