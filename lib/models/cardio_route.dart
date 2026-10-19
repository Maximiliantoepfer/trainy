import 'dart:math' as math;

/// Route data is local. Segment IDs survive decimation so GPS outages never
/// become fictitious straight route lines.
class RoutePoint {
  const RoutePoint(this.latitude, this.longitude, this.segment);
  final double latitude, longitude;
  final int segment;
}

List<List<RoutePoint>> routeSegments(List<Map<String, dynamic>> samples) {
  final segments = <List<RoutePoint>>[];
  int? previousTime, previousSegment;
  for (final sample in samples) {
    final lat = (sample['latitude'] as num?)?.toDouble(),
        lon = (sample['longitude'] as num?)?.toDouble();
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      previousTime = null;
      continue;
    }
    final time = (sample['timestamp'] as num?)?.toInt();
    final stored = (sample['routeSegment'] as num?)?.toInt();
    final gap =
        stored != null
            ? stored != previousSegment
            : previousTime == null ||
                time == null ||
                time - previousTime > 15000;
    if (segments.isEmpty || gap) segments.add([]);
    segments.last.add(RoutePoint(lat, lon, segments.length - 1));
    previousTime = time;
    previousSegment = stored;
  }
  return segments;
}

/// Normalize longitude around the first point (routes crossing the date line).
double routeLongitude(double longitude, double origin) =>
    origin + ((longitude - origin + 180) % 360) - 180;
double routeX(RoutePoint p, RoutePoint first) =>
    routeLongitude(p.longitude, first.longitude) *
    math.cos(first.latitude * math.pi / 180);
