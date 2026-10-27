import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/services/generated/health_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/com/example/trainy/HealthApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.example.trainy',
      errorClassName: 'HealthError',
    ),
    swiftOut: 'ios/Runner/HealthApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'HealthPigeonError'),
  ),
)
class HealthAccess {
  HealthAccess({
    required this.available,
    required this.readState,
    required this.canWrite,
    required this.ownSource,
  });
  bool available;
  // granted, limited, denied, unknown (HealthKit deliberately hides read access).
  String readState;
  bool canWrite;
  String ownSource;
}

class HealthRoutePoint {
  HealthRoutePoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
  });
  int timestamp;
  double latitude;
  double longitude;
  double? accuracy;
  double? altitude;
}

class HealthWorkout {
  HealthWorkout({
    required this.id,
    required this.source,
    required this.name,
    required this.sport,
    required this.start,
    required this.end,
    required this.indoor,
    this.distance,
    this.activeSeconds,
    this.averageHeartRate,
    this.device,
    this.clientId,
  });
  String id;
  String source;
  String name;
  String sport;
  int start;
  int end;
  bool indoor;
  double? distance;
  double? activeSeconds;
  double? averageHeartRate;
  String? device;
  String? clientId;
}

class HealthRoute {
  HealthRoute({required this.state, required this.points});
  // available, noData, denied, consentRequired
  String state;
  List<HealthRoutePoint> points;
}

@HostApi()
abstract class HealthHostApi {
  @async
  HealthAccess access(bool request, bool write, bool heartRate, bool route);
  @async
  List<HealthWorkout> workouts(int start, int end);
  @async
  HealthRoute route(String workoutId, bool allowPrompt);
  @async
  void openSettings();
  @async
  String saveWorkout(HealthWorkout workout);
  @async
  void saveRoute(String workoutId, List<HealthRoutePoint> points);
}
