import '../models/running_preferences.dart';

/// Preference ranking never truncates a named route. Time remains an estimate.
abstract final class RunningRoutes {
  static FavoriteRunningRoute? select(
    List<FavoriteRunningRoute> routes, {
    required int weekday,
    required double maximumMeters,
    double minimumMeters = 0,
    required double defaultMeters,
  }) {
    final candidates = [
      ...routes.where((r) => r.weekdays.contains(weekday)),
      ...routes.where((r) => !r.weekdays.contains(weekday)),
      FavoriteRunningRoute(id: 'default', meters: defaultMeters),
    ];
    return candidates
        .where((r) => r.meters <= maximumMeters && r.meters >= minimumMeters)
        .firstOrNull;
  }
}
