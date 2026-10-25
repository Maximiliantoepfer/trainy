import 'package:flutter_test/flutter_test.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/services/cardio_speech.dart';

void main() {
  test('spoken durations include units without ambiguous clock punctuation', () {
    expect(CardioSpeech.duration(570, 'de'), '9 Minuten 30 Sekunden');
    expect(CardioSpeech.duration(61, 'en'), '1 minute 1 second');
    expect(CardioSpeech.pace(1000 / 570, DistanceSystem.metric, 'de'), '9 Minuten 30 Sekunden pro Kilometer');
    expect(CardioSpeech.pace(1609.344 / 600, DistanceSystem.imperial, 'en'), '10 minutes per mile');
  });
}
