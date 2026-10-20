import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/services/app_database.dart';
import 'package:trainy/services/data_operation.dart';
import 'package:trainy/services/data_lifecycle_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'timers from an earlier operation cannot inherit ownership of a later reset',
    () async {
      final gate = DataOperation();
      late Zone retired;
      await gate.run('first', () async {
        retired = Zone.current;
      });
      expect(retired.run(() => gate.ownsOperation), isFalse);
      await gate.run('second', () async {
        expect(retired.run(() => gate.ownsOperation), isFalse);
        await expectLater(
          retired.run(() => gate.run('stale-poll', () async {})),
          throwsA(isA<DataOperationFailure>()),
        );
      });
    },
  );

  test(
    'background backup keeps workout controls usable; local replacement blocks',
    () async {
      final gate = DataOperation();
      await gate.run('backup', () async {
        expect(gate.isBusy, isTrue);
        expect(gate.blocksInteraction, isFalse);
        await gate.mutateLocal(() async {
          expect(gate.blocksInteraction, isTrue);
        });
        expect(gate.blocksInteraction, isFalse);
      }, blocking: false);
      expect(gate.isBusy, isFalse);
    },
  );

  test(
    'exclusive operations reject competition but allow owning steps',
    () async {
      final gate = DataOperation();
      final release = Completer<void>();
      final started = Completer<void>();
      final task = gate.run('delete', () async {
        await gate.run('child', () async {});
        started.complete();
        await release.future;
      });
      await started.future;
      await expectLater(
        gate.run('backup', () async {}),
        throwsA(
          isA<DataOperationFailure>().having(
            (e) => e.code,
            'code',
            'operation-in-progress',
          ),
        ),
      );
      release.complete();
      await task;
      expect(gate.isBusy, isFalse);
    },
  );

  test(
    'local mutation drains participants and resumes after failure',
    () async {
      final gate = DataOperation();
      final calls = <String>[];
      gate.register(
        calls,
        () async {
          calls.add('pause');
        },
        () {
          calls.add('resume');
        },
      );
      await expectLater(
        gate.mutateLocal(() async {
          calls.add('mutate');
          throw PlatformException(code: 'test-code', message: 'secret');
        }),
        throwsA(
          isA<DataOperationFailure>().having(
            (e) => e.toString(),
            'sanitized',
            isNot(contains('secret')),
          ),
        ),
      );
      expect(calls, ['pause', 'mutate', 'resume']);
      expect(gate.isBusy, isFalse);
      expect(gate.databaseUnavailable, isFalse);
    },
  );

  group('local lifecycle on isolated files', () {
    late Directory directory;
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      directory = await Directory.systemTemp.createTemp(
        'trainy-lifecycle-test-',
      );
      await databaseFactory.setDatabasesPath(directory.path);
      SharedPreferences.setMockInitialValues({
        'theme': 'dark',
        'sentinel': 'keep',
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path,
          );
    });
    tearDown(() async {
      await AppDatabase.instance.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      await directory.delete(recursive: true);
    });

    test(
      'reset recreates only training database and retains settings',
      () async {
        final connections = await Future.wait(
          List.generate(8, (_) => AppDatabase.instance.database),
        );
        expect(
          connections.every((db) => identical(db, connections.first)),
          isTrue,
        );
        await connections.first.insert('app_meta', {
          'key': 'sentinel',
          'value': 'remove',
        });
        await DataLifecycleCoordinator.instance.resetLocalTrainingData();
        final db = await AppDatabase.instance.database;
        await AppDatabase.instance.assertIntegrity();
        expect(
          await db.query('app_meta', where: 'key = ?', whereArgs: ['sentinel']),
          isEmpty,
        );
        expect(
          (await SharedPreferences.getInstance()).getString('theme'),
          'dark',
        );
        await DataLifecycleCoordinator.instance.resetLocalTrainingData();
        await AppDatabase.instance.assertIntegrity();
      },
    );

    test(
      'logout alone never completes an unconfirmed account deletion',
      () async {
        final lifecycle = DataLifecycleCoordinator.instance;
        await lifecycle.markAccountDeletionPending(
          uid: 'test-user',
          phase: 'cloud',
        );
        await lifecycle.completePendingAccountDeletionIfNeeded(
          isSignedIn: false,
        );
        expect(
          (await SharedPreferences.getInstance()).getString('sentinel'),
          'keep',
        );
        await lifecycle.markAccountDeletionPending(
          uid: 'test-user',
          phase: 'authDeleted',
        );
        await lifecycle.completePendingAccountDeletionIfNeeded(
          isSignedIn: false,
        );
        expect(
          (await SharedPreferences.getInstance()).getString('sentinel'),
          isNull,
        );
        expect(await lifecycle.hasPendingAccountDeletion(), isFalse);
        await AppDatabase.instance.assertIntegrity();
      },
    );
  });
}
