import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';

import 'support/confirmed_profiles.dart';
import 'package:trainy/services/profile_readiness.dart';

void main() {
  late Database db;
  late TrainingProgramRepository repo;
  late CardioRepository cardio;
  final start = DateTime(2030, 1, 7); // Monday, safely in the future.
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchemaV2.schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, _) => DatabaseSchemaV2.create(db),
      ),
    );
    final service = DatabaseService(database: db);
    repo = TrainingProgramRepository(database: service);
    cardio = CardioRepository(database: service);
    await seedProfiles(db);
  });
  tearDown(() async {
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await db.close();
  });
  TrainingProgram strength(String name) => TrainingProgram(
    name: name,
    start: start,
    slots: ProgramSplits.slots([1, 3, 5], 'fullBody'),
  );
  RunningPlanProposal proposal() => RunningPlanGenerator().generate(
    const AthleteRunningProfile(
      setupVersion: 1,
      confirmedAnswers: confirmedAnswers,
      referenceKind: 'normal',
      referenceSeconds: 2700,
      continuousMinutes: 45,
      canRunFiveKm: true,
      recentRunsPerWeek: 2,
      level: RunningLevel.beginner,
    ),
    RunningPlanRequest(targetMeters: 5000, startDate: start),
    (s) => s,
  );

  test(
    'editing a saved run in the plan preview preserves its ID, date and neighbours',
    () async {
      await repo.initialize();
      final p = strength('Mixed').copyWith(runningDays: [2, 4, 6]);
      final generated = proposal();
      await repo.save(p, running: generated);
      final before = await cardio.occurrences();
      final original = before.first;
      final changed = ScheduledCardioWorkout(
        id: original.id,
        planId: original.planId,
        date: before[1].date,
        workout: CardioWorkout.fromJson({
          ...original.workout.toJson(),
          'name': 'My progression',
        }),
      );
      final edited = RunningPlanProposal(
        id: generated.id,
        request: generated.request,
        baseWeeks: generated.baseWeeks,
        warnings: generated.warnings,
        occurrences: [for (final o in before) o.id == changed.id ? changed : o],
      );
      await repo.save(p, running: edited, runningEdits: {changed.id});
      final after = await cardio.occurrences();
      expect(
        after.where((o) => o.id == changed.id).single.workout.name,
        'My progression',
      );
      expect(after.where((o) => o.id == changed.id).single.date, changed.date);
      expect(after.length, before.length);
      await repo.save(p, running: edited, runningEdits: {changed.id});
      expect((await cardio.occurrences()).length, before.length);
      final invalid = ScheduledCardioWorkout(
        id: changed.id,
        planId: changed.planId,
        date: start.subtract(const Duration(days: 1)),
        workout: changed.workout,
      );
      await expectLater(
        repo.save(
          p,
          running: RunningPlanProposal(
            id: generated.id,
            request: generated.request,
            baseWeeks: generated.baseWeeks,
            warnings: [],
            occurrences: [invalid],
          ),
          runningEdits: {invalid.id},
        ),
        throwsStateError,
      );
      expect(
        (await cardio.occurrences())
            .where((o) => o.id == changed.id)
            .single
            .date,
        changed.date,
      );
    },
  );

  test(
    'one active plan; sport blocks persist independently and slots are not fake workouts',
    () async {
      await repo.initialize();
      final first = strength('Strength'), second = strength('Another');
      await repo.save(first);
      await repo.save(second);
      expect(await repo.activeId(), second.id);
      expect((await repo.plans()).where((p) => p.status == 'active').length, 1);
      await repo.activate(first.id);
      final combined = first.copyWith(runningDays: [2, 4, 6]);
      await repo.save(combined, running: proposal());
      final entries = await repo.entries(
        combined,
        start,
        start.add(const Duration(days: 7)),
      );
      expect(entries.where((e) => e.kind == 'strength').length, 3);
      expect(
        entries.where((e) => e.kind == 'strength').every((e) => e.needsWorkout),
        isTrue,
      );
      final before = await db.query('cardio_occurrences');
      await repo.save(combined.copyWith(strengthGoal: 'buildMuscle'));
      expect(await db.query('cardio_occurrences'), before);
      expect(
        (await repo.plans())
            .firstWhere((p) => p.id == first.id)
            .slots
            .map((s) => s.id),
        first.slots.map((s) => s.id),
      );
    },
  );

  test(
    'move one strength occurrence across week; future move keeps earlier weeks',
    () async {
      await repo.initialize();
      var p = TrainingProgram(
        name: 'Monday',
        start: start,
        slots: [ProgramSlot(weekday: 1, label: 'fullBody')],
      );
      await repo.save(p);
      final entry =
          (await repo.entries(
            p,
            start,
            start.add(const Duration(days: 7)),
          )).single;
      await repo.moveStrength(
        p,
        entry,
        start.add(const Duration(days: 8)),
        future: false,
      );
      expect(
        await repo.entries(p, start, start.add(const Duration(days: 7))),
        isEmpty,
      );
      expect(
        (await repo.entries(
          p,
          start.add(const Duration(days: 7)),
          start.add(const Duration(days: 14)),
        )).length,
        2,
      );
      final later =
          (await repo.entries(
            p,
            start.add(const Duration(days: 14)),
            start.add(const Duration(days: 21)),
          )).single;
      await repo.moveStrength(
        p,
        later,
        start.add(const Duration(days: 16)),
        future: true,
      );
      p = (await repo.plans()).single;
      final future = await repo.entries(
        p,
        start.add(const Duration(days: 14)),
        start.add(const Duration(days: 35)),
      );
      expect(future.length, 3);
      expect(future.every((e) => e.date.weekday == 3), isTrue);
      expect(
        (await repo.entries(
          p,
          start.add(const Duration(days: 7)),
          start.add(const Duration(days: 14)),
        )).length,
        2,
      );
    },
  );

  test('alternating split preserves parity when moved across weeks', () async {
    var p = TrainingProgram(
      name: 'Alternating',
      start: start,
      slots: [ProgramSlot(weekday: 1, label: 'upper', cycleWeek: 1)],
    );
    await repo.save(p);
    final e =
        (await repo.entries(
          p,
          start,
          start.add(const Duration(days: 7)),
        )).single;
    await repo.moveStrength(
      p,
      e,
      start.add(const Duration(days: 8)),
      future: true,
    );
    p = (await repo.plans()).single;
    final dates = (await repo.entries(
      p,
      start,
      start.add(const Duration(days: 30)),
    )).map((e) => dateKey(e.date));
    expect(dates, ['2030-01-15', '2030-01-29']);
  });

  test(
    'regeneration preserves moved, edited and completed runs without duplicating their original dates',
    () async {
      var p = strength('Mixed').copyWith(runningDays: [1, 3, 5]);
      await repo.save(p, running: proposal());
      final before = await cardio.occurrences();
      final moved = before[0], completed = before[1];
      await cardio.move(moved, moved.date.add(const Duration(days: 1)));
      await db.update(
        'cardio_occurrences',
        {'status': 'completed'},
        where: 'id=?',
        whereArgs: [completed.id],
      );
      final lockedRows = await db.query(
        'cardio_occurrences',
        where: 'id IN (?,?)',
        whereArgs: [moved.id, completed.id],
        orderBy: 'id',
      );
      await repo.save(p, running: proposal());
      expect(
        await db.query(
          'cardio_occurrences',
          where: 'id IN (?,?)',
          whereArgs: [moved.id, completed.id],
          orderBy: 'id',
        ),
        lockedRows,
      );
      expect((await cardio.occurrences()).length, before.length);
      expect(
        (await cardio.occurrences()).any((o) => o.date == moved.date),
        isFalse,
      );
      p = (await repo.plans()).single;
      await repo.save(p.copyWith(runningDays: []));
      final remaining = await cardio.occurrences();
      expect(remaining.length, 2);
      expect((await repo.plans()).single.slots.length, 3);
    },
  );

  test(
    'legacy migration preserves ids, requires selection for multiple active plans, is idempotent',
    () async {
      for (final id in ['legacy-a', 'legacy-b']) {
        await db.insert('training_plans', {
          'id': id,
          'name': id,
          'status': 'active',
          'created_at_utc': 1,
          'updated_at_utc': 1,
        });
        await db.insert('cardio_plans', {
          'id': id,
          'request_json': jsonEncode(
            RunningPlanRequest(targetMeters: 5000, startDate: start).toJson(),
          ),
        });
        await db.insert('cardio_occurrences', {
          'id': 'run-$id',
          'plan_id': id,
          'local_date': dateKey(start),
          'workout_json': jsonEncode(
            CardioWorkout(name: 'Old run', steps: [CardioStep()]).toJson(),
          ),
        });
      }
      await repo.initialize();
      expect(await repo.activeId(), isNull);
      expect((await repo.plans()).map((p) => p.id).toSet(), {
        'legacy-a',
        'legacy-b',
      });
      await repo.initialize();
      expect((await repo.plans()).length, 2);
      expect((await cardio.occurrences()).map((o) => o.id).toSet(), {
        'run-legacy-a',
        'run-legacy-b',
      });
      await repo.activate('legacy-b');
      expect(await repo.activeId(), 'legacy-b');
    },
  );

  test(
    'profiles separate global preferences; unknowns and partial pulses persist',
    () async {
      await repo.initialize();
      await repo.saveUserProfile(
        const UserTrainingProfile(
          units: DistanceSystem.imperial,
          strengthLevel: 'experienced',
        ),
      );
      var p = await cardio.profile();
      p = AthleteRunningProfile.fromJson({
        ...p.toJson(),
        'restingHeartRate': 60,
        'canRunFiveKm': null,
        'recentRunsPerWeek': null,
      });
      await cardio.saveProfile(p);
      final restored = await cardio.profile();
      expect(restored.maximumHeartRate, isNull);
      expect(restored.restingHeartRate, 60);
      expect(restored.recentRunsPerWeek, isNull);
      expect((await repo.userProfile()).strengthLevel, 'experienced');
      expect((await repo.userProfile()).units, DistanceSystem.imperial);
      await repo.saveDraft('plan:new', {'step': 2, 'name': 'Draft'});
      expect((await repo.draft('plan:new'))!['name'], 'Draft');
    },
  );

  test(
    'editing strength assignment preserves past placement and one session completes only one slot',
    () async {
      for (final id in ['a', 'b']) {
        await db.insert('workout_templates', {
          'id': id,
          'name': id,
          'created_at_utc': 1,
          'updated_at_utc': 1,
        });
      }
      final now = DateTime.now(),
          past = DateTime.now().subtract(const Duration(days: 14));
      final p = TrainingProgram(
        name: 'History',
        start: DateTime(past.year, past.month, past.day),
        slots: [
          ProgramSlot(weekday: past.weekday, label: 'fullBody', workoutId: 'a'),
          ProgramSlot(weekday: past.weekday, label: 'fullBody', workoutId: 'a'),
        ],
      );
      await repo.save(p);
      await db.insert('activity_sessions', {
        'id': 'completed-strength',
        'workout_id': 'a',
        'activity_type': 'strength',
        'status': 'completed',
        'name_snapshot': 'Original name',
        'started_at_utc': past.millisecondsSinceEpoch,
        'ended_at_utc': past.millisecondsSinceEpoch + 1000,
        'timezone_offset_minutes': 0,
        'created_at_utc': 1,
      });
      final from = DateTime(past.year, past.month, past.day),
          to = DateTime(past.year, past.month, past.day + 1);
      final oldEntries = await repo.entries(p, from, to);
      expect(oldEntries.where((e) => e.completed), isEmpty);
      await db.insert('strength_session_links', {
        'occurrence_id': oldEntries.first.id,
        'plan_id': p.id,
        'session_id': 'completed-strength',
      });
      final linked = await repo.entries(p, from, to);
      expect(linked.where((e) => e.completed).length, 1);
      expect(linked.firstWhere((e) => e.completed).name, 'Original name');
      await repo.save(
        p.copyWith(
          slots: [p.slots.first.copyWith(workoutId: 'b'), p.slots.last],
        ),
      );
      final revised = (await repo.plans()).single;
      expect((await repo.entries(revised, from, to)).map((e) => e.workoutId), [
        'a',
        'a',
      ]);
      final next = await repo.entries(
        revised,
        DateTime(now.year, now.month, now.day),
        DateTime(now.year, now.month, now.day + 7),
      );
      expect(next.map((e) => e.workoutId).toSet(), {'a', 'b'});
      expect(
        (await db.query('activity_sessions')).single['name_snapshot'],
        'Original name',
      );
    },
  );

  test(
    'continuous beginner gets light week-2 fartlek; incomplete runner is rejected',
    () {
      final p = proposal();
      final week2 = p.occurrences.where(
        (o) =>
            calendarDays(o.date, start) >= 7 &&
            calendarDays(o.date, start) < 14,
      );
      expect(
        p.occurrences.take(3).any((o) => o.workout.templateCode == 'runWalk'),
        isFalse,
      );
      expect(week2.any((o) => o.workout.templateCode == 'fartlek'), isTrue);
      expect(
        week2
            .expand((o) => o.workout.steps)
            .every(
              (s) => [
                CardioIntensity.easy,
                CardioIntensity.steady,
                CardioIntensity.interval,
              ].contains(s.intensity),
            ),
        isTrue,
      );
      expect(
        () => RunningPlanGenerator().generate(
          const AthleteRunningProfile(),
          RunningPlanRequest(targetMeters: 5000, startDate: start),
          (s) => s,
        ),
        throwsA(isA<ProfileIncomplete>()),
      );
      expect(ProgramSplits.recommended(3), 'fullBody');
      expect(ProgramSplits.recommended(4), 'upperLower');
      expect(ProgramSplits.slots([1, 2, 3, 4, 5], 'upperLower').length, 10);
      expect(ProgramSplits.recommended(6), 'pushPullLegs');
    },
  );
}
