import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trainy/services/generated/cardio_api.g.dart';

/// Device smoke test. Never discards an existing session or touches user SQLite data.
/// Android setup: grant ACTIVITY_RECOGNITION to com.example.trainy on the test emulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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
