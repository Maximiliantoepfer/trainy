// lib/screens/progress_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/progress_provider.dart';
import '../models/workout_entry.dart';
import 'workout_entry_detail_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Genau einmal initial laden (kein mehrfaches fetchen bei Rebuilds)
    if (!_loadedOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ProgressProvider>().loadData();
        }
      });
      _loadedOnce = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProgressProvider>();
    final entries = provider.entries;

    return Scaffold(
      appBar: AppBar(title: const Text('Fortschritt')),
      body:
          provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemBuilder: (_, i) => _EntryCard(entry: entries[i]),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: entries.length,
              ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, size: 72),
            const SizedBox(height: 12),
            Text(
              'Noch keine Einträge',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Starte ein Workout und erfasse Sätze, dann erscheinen sie hier.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final WorkoutEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.date;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';

    // simple summary: Summe Sätze über alle Übungen + Gesamtdauer
    int totalSets = 0;
    int totalDuration = 0;
    entry.results.forEach((_, v) {
      final sets = v['sets'];
      if (sets is int) totalSets += sets;
      if (sets is String) {
        final s = int.tryParse(sets);
        if (s != null) totalSets += s;
      }
      final dur = v['duration'];
      if (dur is int) totalDuration += dur;
      if (dur is String) {
        final d = int.tryParse(dur);
        if (d != null) totalDuration += d;
      }
    });

    return Card(
      child: ListTile(
        title: Text(
          'Workout #${entry.workoutId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$dateStr · $totalSets Sätze${totalDuration > 0 ? ' · ${_formatDuration(totalDuration)}' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkoutEntryDetailScreen(entry: entry),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
