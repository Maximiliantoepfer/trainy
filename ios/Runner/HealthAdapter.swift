import Foundation
import HealthKit
import CoreLocation
import UIKit

/// HealthKit deliberately does not reveal whether a read permission was denied.
final class HealthAdapter: HealthHostApi {
  private let store = HKHealthStore()
  private let workoutType = HKObjectType.workoutType()
  private var own: String { Bundle.main.bundleIdentifier ?? "com.example.trainy" }
  private func finish<T>(_ result: Result<T, Error>, _ completion: @escaping (Result<T, Error>) -> Void) {
    DispatchQueue.main.async { completion(result) }
  }
  private func failure(_ code: String) -> Error { NSError(domain: "Trainy.Health", code: 1, userInfo: [NSLocalizedDescriptionKey: code]) }
  private func state() -> HealthAccess {
    HealthAccess(available: HKHealthStore.isHealthDataAvailable(), readState: "unknown",
      canWrite: store.authorizationStatus(for: workoutType) == .sharingAuthorized, ownSource: own)
  }
  func access(request: Bool, write: Bool, heartRate: Bool, route: Bool,
              completion: @escaping (Result<HealthAccess, Error>) -> Void) {
    guard HKHealthStore.isHealthDataAvailable(), request else { finish(.success(state()), completion); return }
    var read: Set<HKObjectType> = [workoutType, HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
      HKQuantityType.quantityType(forIdentifier: .distanceCycling)!]
    if heartRate { read.insert(HKQuantityType.quantityType(forIdentifier: .heartRate)!) }
    if route { read.insert(HKSeriesType.workoutRoute()) }
    var share = Set<HKSampleType>()
    if write { share.insert(workoutType) }
    if write && route { share.insert(HKSeriesType.workoutRoute()) }
    store.requestAuthorization(toShare: share, read: read) { _, error in
      if let error = error { self.finish(.failure(error), completion) }
      else { self.finish(.success(self.state()), completion) }
    }
  }
  private func query(_ type: HKSampleType, _ predicate: NSPredicate?, _ completion: @escaping (Result<[HKSample], Error>) -> Void) {
    store.execute(HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) {
      _, samples, error in
      if let error = error { self.finish(.failure(error), completion) }
      else { self.finish(.success(samples ?? []), completion) }
    })
  }
  func workouts(start: Int64, end: Int64, completion: @escaping (Result<[HealthWorkout], Error>) -> Void) {
    query(workoutType, HKQuery.predicateForSamples(withStart: date(start), end: date(end), options: .strictStartDate)) { result in
      switch result {
      case .failure(let error): completion(.failure(error))
      case .success(let samples):
        let workouts = samples.compactMap { $0 as? HKWorkout }.filter { self.sport($0.workoutActivityType) != nil }
        let group = DispatchGroup()
        var records = [HealthWorkout]()
        for workout in workouts {
          group.enter()
          // Associated samples, not a time-window sum across unrelated watches/providers.
          self.query(HKQuantityType.quantityType(forIdentifier: .heartRate)!, HKQuery.predicateForObjects(from: workout)) { pulseResult in
            let pulse = (try? pulseResult.get())?.compactMap { $0 as? HKQuantitySample }.filter {
              $0.sourceRevision.source.bundleIdentifier == workout.sourceRevision.source.bundleIdentifier &&
              $0.device == workout.device && $0.startDate >= workout.startDate && $0.endDate <= workout.endDate
            }.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
            let average = pulse.flatMap { $0.isEmpty ? nil : $0.reduce(0, +) / Double($0.count) }
            let distance = workout.totalDistance?.doubleValue(for: .meter())
            records.append(HealthWorkout(id: workout.uuid.uuidString, source: workout.sourceRevision.source.bundleIdentifier,
              name: self.sport(workout.workoutActivityType)!, sport: self.sport(workout.workoutActivityType)!,
              start: self.millis(workout.startDate), end: self.millis(workout.endDate),
              indoor: workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool ?? false,
              distance: distance.flatMap { $0 > 0 && $0.isFinite ? $0 : nil }, activeSeconds: workout.duration,
              averageHeartRate: average, device: workout.device?.localIdentifier,
              clientId: workout.metadata?[HKMetadataKeySyncIdentifier] as? String))
            group.leave()
          }
        }
        group.notify(queue: .main) { completion(.success(records)) }
      }
    }
  }
  private func workout(_ id: String, _ completion: @escaping (Result<HKWorkout, Error>) -> Void) {
    guard let uuid = UUID(uuidString: id) else { finish(.failure(failure("invalid_workout_id")), completion); return }
    query(workoutType, HKQuery.predicateForObject(with: uuid)) { result in
      completion(result.flatMap { samples in
        guard let workout = samples.first as? HKWorkout else { return .failure(self.failure("workout_not_readable")) }
        return .success(workout)
      })
    }
  }
  func openSettings(completion: @escaping (Result<Void, Error>) -> Void) {
    DispatchQueue.main.async {
      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) { success in
        completion(success ? .success(()) : .failure(self.failure("settings_unavailable")))
      }
    }
  }
  func route(workoutId: String, allowPrompt: Bool, completion: @escaping (Result<HealthRoute, Error>) -> Void) {
    access(request: allowPrompt, write: false, heartRate: false, route: true) { access in
      if case .failure(let error) = access { completion(.failure(error)); return }
      self.workout(workoutId) { result in
        switch result {
        case .failure(let error): completion(.failure(error))
        case .success(let workout):
          self.query(HKSeriesType.workoutRoute(), HKQuery.predicateForObjects(from: workout)) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let samples):
              let routes = samples.compactMap { $0 as? HKWorkoutRoute }
              guard !routes.isEmpty else { completion(.success(HealthRoute(state: "noData", points: []))); return }
              let group = DispatchGroup(); var points = [HealthRoutePoint](); var routeError: Error?
              for route in routes {
                group.enter()
                self.store.execute(HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                  DispatchQueue.main.async {
                    if let error = error { routeError = error }
                    points += (locations ?? []).map { HealthRoutePoint(timestamp: self.millis($0.timestamp),
                      latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude,
                      accuracy: $0.horizontalAccuracy, altitude: $0.altitude) }
                    if done || error != nil { group.leave() }
                  }
                })
              }
              group.notify(queue: .main) {
                if let error = routeError { completion(.failure(error)) }
                else { completion(.success(HealthRoute(state: "available", points: points.sorted { $0.timestamp < $1.timestamp }))) }
              }
            }
          }
        }
      }
    }
  }
  func saveWorkout(workout: HealthWorkout, completion: @escaping (Result<String, Error>) -> Void) {
    guard let clientId = workout.clientId, !clientId.isEmpty, let type = activity(workout.sport), workout.end > workout.start
      else { finish(.failure(failure("invalid_workout")), completion); return }
    let start = date(workout.start), end = date(workout.end)
    // Includes legacy exports so updating the adapter does not create a second workout.
    query(workoutType, HKQuery.predicateForSamples(withStart: start, end: end, options: [])) { result in
      switch result {
      case .failure(let error): completion(.failure(error))
      case .success(let samples):
        let matches = samples.compactMap { $0 as? HKWorkout }.filter {
          $0.sourceRevision.source.bundleIdentifier == self.own &&
          (($0.metadata?[HKMetadataKeySyncIdentifier] as? String == clientId) ||
            ($0.startDate == start && $0.endDate == end && $0.workoutActivityType == type))
        }
        guard matches.count <= 1 else { completion(.failure(self.failure("ambiguous_legacy_export"))); return }
        if let match = matches.first { completion(.success(match.uuid.uuidString)); return }
        let distance = workout.distance.flatMap { $0 > 0 && $0.isFinite ? HKQuantity(unit: .meter(), doubleValue: $0) : nil }
        let saved = HKWorkout(activityType: type, start: start, end: end,
          duration: min(workout.activeSeconds ?? end.timeIntervalSince(start), end.timeIntervalSince(start)),
          totalEnergyBurned: nil, totalDistance: distance, metadata: [HKMetadataKeySyncIdentifier: clientId,
            HKMetadataKeySyncVersion: 1, HKMetadataKeyIndoorWorkout: workout.indoor])
        self.store.save(saved) { success, error in
          self.finish(success ? .success(saved.uuid.uuidString) : .failure(error ?? self.failure("export_failed")), completion)
        }
      }
    }
  }
  func saveRoute(workoutId: String, points: [HealthRoutePoint], completion: @escaping (Result<Void, Error>) -> Void) {
    workout(workoutId) { result in
      switch result {
      case .failure(let error): completion(.failure(error))
      case .success(let workout):
        guard workout.sourceRevision.source.bundleIdentifier == self.own else { completion(.failure(self.failure("not_own_workout"))); return }
        self.query(HKSeriesType.workoutRoute(), HKQuery.predicateForObjects(from: workout)) { result in
          switch result {
          case .failure(let error): completion(.failure(error))
          case .success(let routes):
            if !routes.isEmpty { completion(.success(())); return }
            let locations = points.sorted { $0.timestamp < $1.timestamp }.filter {
              $0.timestamp >= self.millis(workout.startDate) && $0.timestamp <= self.millis(workout.endDate) &&
              $0.latitude.isFinite && abs($0.latitude) <= 90 && $0.longitude.isFinite && abs($0.longitude) <= 180
            }.map { CLLocation(coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
              altitude: $0.altitude ?? 0, horizontalAccuracy: $0.accuracy ?? -1, verticalAccuracy: -1, timestamp: self.date($0.timestamp)) }
            guard !locations.isEmpty else { completion(.failure(self.failure("empty_route"))); return }
            let builder = HKWorkoutRouteBuilder(healthStore: self.store, device: .local())
            builder.insertRouteData(locations) { success, error in
              guard success else { self.finish(.failure(error ?? self.failure("route_insert_failed")), completion); return }
              builder.finishRoute(with: workout, metadata: nil) { route, error in
                self.finish(route != nil ? .success(()) : .failure(error ?? self.failure("route_finish_failed")), completion)
              }
            }
          }
        }
      }
    }
  }
  private func date(_ millis: Int64) -> Date { Date(timeIntervalSince1970: Double(millis) / 1000) }
  private func millis(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }
  private func sport(_ activity: HKWorkoutActivityType) -> String? {
    switch activity {
    case .running: return "running"
    case .walking: return "walking"
    case .cycling: return "cycling"
    case .stairClimbing, .stairs: return "stepper"
    case .elliptical: return "elliptical"
    case .rowing: return "rowing"
    default: return nil
    }
  }
  private func activity(_ sport: String) -> HKWorkoutActivityType? {
    switch sport {
    case "running": return .running
    case "walking": return .walking
    case "cycling": return .cycling
    case "stepper": return .stairClimbing
    case "elliptical": return .elliptical
    case "rowing": return .rowing
    default: return nil
    }
  }
}
