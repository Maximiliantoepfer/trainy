import '../models/cardio.dart';

/// Speech uses words and canonical seconds; display clocks are not TTS text.
abstract final class CardioSpeech {
  static String duration(double seconds, String locale) {
    final value = seconds.round();
    final minutes = value ~/ 60, remainder = value % 60;
    final de = locale.startsWith('de');
    return [
      if (minutes > 0) '$minutes ${de ? (minutes == 1 ? 'Minute' : 'Minuten') : (minutes == 1 ? 'minute' : 'minutes')}',
      if (remainder > 0 || minutes == 0) '$remainder ${de ? (remainder == 1 ? 'Sekunde' : 'Sekunden') : (remainder == 1 ? 'second' : 'seconds')}',
    ].join(' ');
  }

  static String pace(double speed, DistanceSystem units, String locale) =>
      '${duration(CardioUnits.distanceUnit(units) / speed, locale)} '
      '${locale.startsWith('de') ? 'pro' : 'per'} '
      '${units == DistanceSystem.metric ? (locale.startsWith('de') ? 'Kilometer' : 'kilometre') : (locale.startsWith('de') ? 'Meile' : 'mile')}';
}
