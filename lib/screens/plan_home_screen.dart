import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/plan_l10n.dart';
import '../providers/training_program_provider.dart';
import '../providers/active_workout_provider.dart';
import '../providers/cardio_provider.dart';
import '../widgets/active_workout_banner.dart';
import '../widgets/motivational_quote_card.dart';
import 'training_plan_screen.dart';
import 'training_library_screen.dart';
import 'cardio_session_screen.dart';

class PlanHomeScreen extends StatefulWidget {
  const PlanHomeScreen({super.key});
  @override
  State<PlanHomeScreen> createState() => _PlanHomeScreenState();
}

class _PlanHomeScreenState extends State<PlanHomeScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingProgramProvider>();
    final active = context.watch<ActiveWorkoutProvider>();
    final cardio = context.watch<CardioProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainy'),
        actions: [
          IconButton(
            tooltip: context.plan('calendar'),
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrainingPlanScreen(initialDate: _date),
                  ),
                ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (active.isActive) ...[
              const ActiveWorkoutBanner(),
              const SizedBox(height: 16),
            ],
            if (cardio.active) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(context.plan('continueWorkout')),
                  subtitle: Text(cardio.runtime?['name'] as String? ?? ''),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CardioSessionScreen(),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (state.active == null)
              const TrainingPlanCard()
            else ...[
              PlanWeekView(
                key: ValueKey('${state.active!.id}:${cardio.history.length}'),
                program: state.active!,
                date: _date,
                onDateChanged: (d) => setState(() => _date = d),
                todayFirst: true,
              ),
              const SizedBox(height: 24),
              const TrainingPlanCard(),
              const SizedBox(height: 16),
              TextButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrainingLibraryScreen(),
                      ),
                    ),
                child: Text(context.plan('withoutPlan')),
              ),
              const SizedBox(height: 24),
              const MotivationalQuoteCard(),
            ],
          ],
        ),
      ),
    );
  }
}
