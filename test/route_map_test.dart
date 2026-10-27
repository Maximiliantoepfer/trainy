import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/widgets/cardio_route_view.dart';

void main() {
  testWidgets(
    'real map accepts mutable headers, reports offline failure, retries and retains local trace',
    (tester) async {
      var offline = true, requests = 0;
      final clients = <http.Client>[];
      final tile = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAAAXNSR0IB2cksfwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAANQTFRF////p8QbyAAAAB9JREFUeJztwQENAAAAwqD3T20ON6AAAAAAAAAAAL4NIQAAAfFnIe4AAAAASUVORK5CYII=',
      );
      final report = FlutterError.onError;
      var expectedFailures = 0;
      FlutterError.onError = (details) {
        if (offline &&
            details.exception is NetworkImageLoadException &&
            (details.exception as NetworkImageLoadException).statusCode ==
                503) {
          expectedFailures++;
        } else {
          report?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = report);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ListView(
              children: [
                CardioRouteView(
                  samples: const [
                    {'latitude': 52.0, 'longitude': 13.0, 'timestamp': 1000},
                    {
                      'latitude': 52.001,
                      'longitude': 13.001,
                      'timestamp': 2000,
                    },
                  ],
                  tileProviderFactory: () {
                    final client = MockClient((request) async {
                      requests++;
                      expect(request.headers['User-Agent'], isNotEmpty);
                      return offline
                          ? http.Response('offline', 503)
                          : http.Response.bytes(tile, 200);
                    });
                    clients.add(client);
                    return NetworkTileProvider(
                      httpClient: client,
                      headers: {},
                      cachingProvider: const DisabledMapCachingProvider(),
                      attemptDecodeOfHttpErrorResponses: false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.tap(find.text('Straßenkarte laden'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Straßenkarte laden'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(requests, greaterThan(0));
      expect(expectedFailures, greaterThan(0));
      expect(find.textContaining('Karte nicht verfügbar'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RouteTracePainter,
        ),
        findsOneWidget,
      );
      offline = false;
      await tester.ensureVisible(find.text('Erneut versuchen'));
      await tester.tap(find.text('Erneut versuchen'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Karte nicht verfügbar'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      for (final client in clients) {
        client.close();
      }
    },
  );
}
