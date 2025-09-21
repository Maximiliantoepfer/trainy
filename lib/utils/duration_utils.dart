class DurationParts {
  final int hours;
  final int minutes;
  final int seconds;

  const DurationParts({this.hours = 0, this.minutes = 0, this.seconds = 0});
}

class DurationFormatter {
  const DurationFormatter._();

  static DurationParts split(int totalSeconds) {
    if (totalSeconds <= 0) {
      return const DurationParts();
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return DurationParts(hours: hours, minutes: minutes, seconds: seconds);
  }

  static int parseTotalSeconds(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return 0;
      return int.tryParse(trimmed) ?? 0;
    }
    return 0;
  }

  static DurationParts fromRaw(dynamic raw) {
    return split(parseTotalSeconds(raw));
  }

  static int totalSecondsFromTexts(
    String? hours,
    String? minutes,
    String? seconds,
  ) {
    final h = _parseUnit(hours);
    final m = _parseUnit(minutes);
    final s = _parseUnit(seconds);
    return (h * 3600) + (m * 60) + s;
  }

  static String digital(int seconds) {
    if (seconds <= 0) return '00:00';
    final parts = split(seconds);
    final h = parts.hours;
    final m = parts.minutes.toString().padLeft(2, '0');
    final s = parts.seconds.toString().padLeft(2, '0');
    if (h > 0) {
      final hh = h.toString().padLeft(2, '0');
      return '$hh:$m:$s';
    }
    return '$m:$s';
  }

  static String verbose(int seconds) {
    if (seconds <= 0) return '0 Sek';
    final parts = split(seconds);
    final buffer = <String>[];

    if (parts.hours > 0) {
      buffer.add('${parts.hours} Std');
    }

    if (parts.hours > 0 || parts.minutes > 0) {
      final mm =
          parts.hours > 0
              ? parts.minutes.toString().padLeft(2, '0')
              : parts.minutes.toString();
      buffer.add('$mm Min');
    }

    final shouldPadSeconds = parts.hours > 0 || parts.minutes > 0;
    final ss =
        shouldPadSeconds
            ? parts.seconds.toString().padLeft(2, '0')
            : parts.seconds.toString();
    buffer.add('$ss Sek');

    return buffer.join(' ');
  }

  static int _parseUnit(String? value) {
    if (value == null) return 0;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 0;
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) return 0;
    return parsed;
  }
}
