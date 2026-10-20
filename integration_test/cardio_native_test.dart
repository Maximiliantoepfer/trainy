import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trainy/services/generated/cardio_api.g.dart';

/// Device smoke test, built as com.example.trainy.integration on Android.
/// Run tool/test_android_integration.ps1 -DeviceId emulator-5554 -Test cardio_native_test.
/// It verifies the APK identity BEFORE Flutter captures it for teardown.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'outdoor recorder accepts an emulator GPS route and preserves pause',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Isolated GPS test'))),
      );
      final api = CardioHostApi();
      expect(await api.state(), isNull);
      expect([
        'ready',
        'ready_silent',
      ], contains(await api.prepare(true, 'en')));
      const id = 'trainy-outdoor-smoke';
      try {
        await api.start(
          jsonEncode({
            'version': 1,
            'sessionId': id,
            'name': 'GPS test',
            'sport': 'running',
            'indoor': false,
            'autoPause': false,
            'locale': 'en',
            'unitMeters': 1000,
            'startedAt': DateTime.now().millisecondsSinceEpoch,
            'messages': <String, String>{},
            'steps': [
              {
                'id': 'easy',
                'amount': 120,
                'goal': 'time',
                'movement': 'run',
                'primaryTarget': 'effort',
              },
            ],
          }),
        );
        Map state = {};
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          state = jsonDecode((await api.state())!) as Map;
          if ((state['distanceMeters'] as num? ?? 0) > 10) break;
        }
        expect(state['gps'], 'gpsReady');
        expect(state['distanceMeters'] as num, greaterThan(10));
        final samples = jsonDecode(await api.samples(-1)) as List;
        expect(samples.length, greaterThan(2));
        expect(samples.every((s) => s['source'] == 'phone_gps'), true);
        await api.pause();
        final distance =
            (jsonDecode((await api.state())!) as Map)['distanceMeters'] as num;
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(
          (jsonDecode((await api.state())!) as Map)['distanceMeters'],
          distance,
        );
        await api.resume();
        await Future<void>.delayed(const Duration(seconds: 2));
        expect((jsonDecode((await api.state())!) as Map)['status'], 'active');
      } finally {
        final raw = await api.state();
        if (raw != null && (jsonDecode(raw) as Map)['sessionId'] == id) {
          await api.finish();
          await api.acknowledge(id);
        }
      }
    },
  );
  testWidgets(
    'native recorder starts, pauses, resumes and commits without a Flutter timer',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Trainy native recorder smoke test')),
        ),
      );
      final api = CardioHostApi();
      expect(
        await api.state(),
        isNull,
        reason:
            'Finish the existing session before running this non-destructive test.',
      );
      final preparation = await api.prepare(false, 'en');
      expect(['ready', 'ready_silent'], contains(preparation));
      const id = 'trainy-native-smoke';
      var owned = false;
      try {
        await api.start(
          jsonEncode({
            'version': 1,
            'sessionId': id,
            'name': 'Native smoke test',
            'sport': 'running',
            'indoor': true,
            'autoPause': false,
            'locale': 'en',
            'unitMeters': 1000,
            'startedAt': DateTime.now().millisecondsSinceEpoch,
            'messages': <String, String>{},
            'steps': [
              for (var i = 0; i < 2; i++)
                {
                  'id': 'interval:$i',
                  'amount': 2,
                  'goal': 'time',
                  'movement': 'run',
                  'primaryTarget': 'effort',
                },
            ],
          }),
        );
        owned = true;
        await Future<void>.delayed(const Duration(seconds: 2));
        await api.pause();
        expect((jsonDecode((await api.state())!) as Map)['status'], 'paused');
        await api.resume();
        for (var attempt = 0; attempt < 24; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final state = jsonDecode((await api.state())!) as Map;
          if (state['status'] == 'completed') break;
        }
        final completed = jsonDecode((await api.state())!) as Map;
        expect(completed['status'], 'completed');
        expect((completed['results'] as List).length, 2);
        expect(completed['activeSeconds'] as num, closeTo(4, .01));
        await api.acknowledge(id);
        owned = false;
        expect(await api.state(), isNull);
      } finally {
        if (owned) {
          final raw = await api.state();
          if (raw != null && (jsonDecode(raw) as Map)['sessionId'] == id) {
            await api.finish();
            await api.acknowledge(id);
          }
        }
      }
    },
  );
}
