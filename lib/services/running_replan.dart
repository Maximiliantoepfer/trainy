import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../models/cardio.dart';
import '../models/training_program.dart';
import '../repositories/cardio_repository.dart';
import 'cardio_training.dart';
import 'running_rules.dart';

class RunningReplanPreview {
  const RunningReplanPreview(
    this.planId,
    this.fingerprint,
    this.before,
    this.after,
    this.request,
    this.profile,
    this.warnings,
  );
  final String planId, fingerprint;
  final List<ScheduledCardioWorkout> before, after;
  final RunningPlanRequest request;
  final AthleteRunningProfile profile;
  final List<String> warnings;
}

class RunningReplan {
  const RunningReplan(this.repository);
  final CardioRepository repository;
  static Future<String> _fingerprint(DatabaseExecutor db, String plan) async =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode([
                await db.query('cardio_preferences'),
                await db.query(
                  'cardio_occurrences',
                  where: 'plan_id=?',
                  whereArgs: [plan],
                  orderBy: 'id',
                ),
                await db.rawQuery('''SELECT s.id, s.status, d.snapshot_json,
                  CASE WHEN s.status='completed' THEN d.runtime_json ELSE NULL END AS runtime_json
                  FROM activity_sessions s JOIN cardio_session_details d ON s.id=d.session_id
                  ORDER BY s.id'''),
                await db.query(
                  'training_programs',
                  where: 'id=?',
                  whereArgs: [plan],
                ),
                await db.query(
                  'cardio_plans',
                  where: 'id=?',
                  whereArgs: [plan],
                ),
                await db.query('active_training_plan'),
              ]),
            ),
          )
          .toString();
  Future<RunningReplanPreview> preview(
    TrainingProgram plan,
    CardioTranslate translate, {
    DateTime? now,
  }) async {
    final fingerprint = await repository.db.transaction(
      (db) => _fingerprint(db, plan.id),
    );
    final profile = await repository.profile();
    final date = now ?? DateTime.now();
    final today = DateTime(date.year, date.month, date.day);
    final request = RunningPlanRequest(
      startDate: today,
      targetMeters: plan.targetMeters,
      targetDate:
          plan.targetDate != null && plan.targetDate!.isAfter(today)
              ? plan.targetDate
              : null,
      targetSeconds: plan.targetSeconds,
      goal: profile.planning.goal,
      hardTrainingDays:
          plan.currentSlots
              .where((s) => s.kind == 'strength' && s.legHeavy)
              .map((s) => s.weekday)
              .toList(),
      fitness: await repository.fitness(now: date),
    );
    final generated = RunningPlanGenerator().generate(
      profile,
      request,
      translate,
    );
    final before =
        (await repository.occurrences())
            .where((o) => o.planId == plan.id && !o.date.isBefore(today))
            .toList();
    bool protected(ScheduledCardioWorkout o) =>
        o.status != 'planned' ||
        o.sessionId != null ||
        o.locked ||
        o.workout.steps.any((s) => s.targetSource == 'manual');
    final protectedRows = before.where(protected).toList();
    final unused = before.where((o) => !protected(o)).toList();
    final after = [...protectedRows];
    for (final next in generated.occurrences) {
      if (protectedRows.any((o) => o.date == next.date)) continue;
      final old =
          unused.where((o) => o.date == next.date).firstOrNull ??
          unused.firstOrNull;
      if (old != null) unused.remove(old);
      after.add(
        ScheduledCardioWorkout(
          id: old?.id ?? next.id,
          planId: plan.id,
          date: next.date,
          workout: CardioWorkout.fromJson({
            ...next.workout.toJson(),
            if (old != null) 'id': old.workout.id,
          }),
        ),
      );
    }
    after.sort((a, b) => a.date.compareTo(b.date));
    if (fingerprint !=
        await repository.db.transaction((db) => _fingerprint(db, plan.id))) {
      throw StateError('stale_proposal');
    }
    return RunningReplanPreview(
      plan.id,
      fingerprint,
      before,
      after,
      request,
      profile,
      generated.warnings,
    );
  }

  Future<void> apply(RunningReplanPreview preview) async =>
      repository.db.transaction((db) async {
        if (preview.fingerprint != await _fingerprint(db, preview.planId)) {
          throw StateError('stale_proposal');
        }
        final today = CardioRepository.dateKey(DateTime.now());
        if (preview.after.any(
          (o) =>
              o.status == 'planned' &&
              o.sessionId == null &&
              !o.locked &&
              CardioRepository.dateKey(o.date).compareTo(today) < 0,
        )) {
          throw StateError('stale_proposal');
        }
        final ids = preview.after.map((o) => o.id).toSet();
        for (final old in preview.before) {
          if (!ids.contains(old.id)) {
            await db.delete(
              'cardio_occurrences',
              where: 'id=?',
              whereArgs: [old.id],
            );
          }
        }
        for (final next in preview.after) {
          if (next.status != 'planned' ||
              next.locked ||
              next.sessionId != null ||
              next.workout.steps.any((s) => s.targetSource == 'manual')) {
            continue;
          }
          next.workout.validate();
          final values = {
            'plan_id': next.planId,
            'local_date': CardioRepository.dateKey(next.date),
            'workout_json': jsonEncode(next.workout.toJson()),
            'status': 'planned',
            'locked': 0,
          };
          final changed = await db.update(
            'cardio_occurrences',
            values,
            where: 'id=?',
            whereArgs: [next.id],
          );
          if (changed == 0) {
            await db.insert('cardio_occurrences', {'id': next.id, ...values});
          }
        }
        await db.update(
          'cardio_plans',
          {'request_json': jsonEncode(preview.request.toJson())},
          where: 'id=?',
          whereArgs: [preview.planId],
        );
        final programRows = await db.query(
          'training_programs',
          where: 'id=?',
          whereArgs: [preview.planId],
        );
        if (programRows.isNotEmpty) {
          final program = TrainingProgram.fromJson(
            jsonDecode(programRows.single['program_json'] as String)
                as Map<String, dynamic>,
          );
          final days =
              preview.after.map((o) => o.date.weekday).toSet().toList()..sort();
          await db.update(
            'training_programs',
            {
              'program_json': jsonEncode(
                program
                    .copyWith(
                      runningDays: days,
                      runningGoal: preview.profile.planning.goal,
                      targetMeters: preview.request.targetMeters,
                      targetDate: preview.request.targetDate,
                      clearTargetDate: preview.request.targetDate == null,
                      targetSeconds: preview.request.targetSeconds,
                      clearTargetTime: preview.request.targetSeconds == null,
                    )
                    .toJson(),
              ),
            },
            where: 'id=?',
            whereArgs: [preview.planId],
          );
        }
        final profileRows = await db.query('cardio_preferences');
        final profile =
            jsonDecode(profileRows.single['profile_json'] as String)
                as Map<String, dynamic>;
        final planning = Map<String, dynamic>.from(
          profile['planning'] as Map? ?? {},
        );
        planning['adaptationHistory'] = [
          ...planning['adaptationHistory'] as List? ?? [],
          {
            'createdAt': DateTime.now().toIso8601String(),
            'reason': 'replan',
            'ruleVersion': RunningRules.bundled.version,
            'fitness': preview.request.fitness?.toJson(),
          },
        ];
        profile['planning'] = planning;
        await db.update('cardio_preferences', {
          'profile_json': jsonEncode(profile),
        }, where: 'id=0');
      });
}
