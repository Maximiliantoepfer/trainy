import Flutter
import UIKit
import XCTest
import CoreLocation
@testable import Runner

class RunnerTests: XCTestCase {
  func testSharedMeasurementContractV2() throws {
    guard #available(iOS 13.4, *) else { throw XCTSkip("Speed accuracy initializer requires iOS 13.4") }
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let bytes = try Data(contentsOf: root.appendingPathComponent("test/fixtures/gps_measurement_v2.json"))
    let document = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    for fixture in try XCTUnwrap(document["cases"] as? [[String: Any]]) {
      let engine = CardioEngine(CardioEngine.fresh(["sessionId": "replay", "indoor": false, "autoPause": false,
        "steps": [["id": "run", "goal": "distance", "amount": 1000.0, "movement": "run"]]]), speak: { _ in })
      engine.state["countdown"] = 0.0
      for p in fixture["samples"] as! [[String: Any]] {
        let received = (p["received"] as! NSNumber).doubleValue, measured = (p["time"] as! NSNumber).doubleValue
        let fix = CLLocation(coordinate: CLLocationCoordinate2D(latitude: (p["lat"] as! NSNumber).doubleValue, longitude: (p["lon"] as! NSNumber).doubleValue),
          altitude: 0, horizontalAccuracy: (p["accuracy"] as! NSNumber).doubleValue, verticalAccuracy: 5,
          course: 0, courseAccuracy: 1, speed: (p["speed"] as? NSNumber)?.doubleValue ?? -1,
          speedAccuracy: (p["speedAccuracy"] as? NSNumber)?.doubleValue ?? -1, timestamp: Date())
        engine.tick(received); _ = engine.location(fix, now: measured, receivedAt: received)
      }
      XCTAssertGreaterThanOrEqual(engine.number("distanceMeters"), (fixture["minMeters"] as! NSNumber).doubleValue, fixture["name"] as! String)
      XCTAssertLessThanOrEqual(engine.number("distanceMeters"), (fixture["maxMeters"] as! NSNumber).doubleValue, fixture["name"] as! String)
      XCTAssertEqual(engine.state["paceQuality"] as? String, fixture["paceQuality"] as? String)
    }
  }
  func testDelayedTickAndLateGpsCrossing() {
    let snapshot: [String: Any] = ["sessionId": "mixed", "indoor": false, "autoPause": false,
      "steps": [["id": "time", "goal": "time", "amount": 5.0, "movement": "run"],
                ["id": "distance", "goal": "distance", "amount": 50.0, "movement": "run"]]]
    let engine = CardioEngine(CardioEngine.fresh(snapshot), speak: { _ in })
    engine.state["countdown"] = 0.0
    engine.tick(0)
    func fix(_ latitude: Double) -> CLLocation { CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 13),
      altitude: 0, horizontalAccuracy: 3, verticalAccuracy: 3, course: 0, speed: 2, timestamp: Date()) }
    _ = engine.location(fix(52), now: 0)
    engine.tick(10)
    _ = engine.location(fix(52.000179864), now: 10)
    XCTAssertEqual(engine.number("stepMeters"), 10, accuracy: 0.15)
    XCTAssertEqual(engine.number("activeSeconds"), 10, accuracy: 0.001)
    let results = engine.state["results"] as! [[String: Any]]
    XCTAssertEqual((results[0]["meters"] as! NSNumber).doubleValue, 10, accuracy: 0.15)
  }
  func testSharedPlatformReplay() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let bytes = try Data(contentsOf: root.appendingPathComponent("test/fixtures/cardio_replay.json"))
    let document = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    for fixture in try XCTUnwrap(document["cases"] as? [[String: Any]]) {
      let snapshot: [String: Any] = ["version": 1, "sessionId": fixture["name"]!,
        "indoor": fixture["indoor"]!, "steps": fixture["steps"]!]
      let engine = CardioEngine(CardioEngine.fresh(snapshot), speak: { _ in })
      engine.state["countdown"] = 0.0
      for tick in try XCTUnwrap(fixture["ticks"] as? [Double]) { engine.tick(tick) }
      XCTAssertEqual(engine.state["status"] as? String, fixture["expectedStatus"] as? String)
      XCTAssertEqual(engine.number("activeSeconds"), (fixture["expectedSeconds"] as! NSNumber).doubleValue, accuracy: 0.001)
      XCTAssertEqual(engine.index, fixture["expectedIndex"] as? Int)
    }
  }

  func testEasyPaceCapNeverRequestsAcceleration() {
    for speed in [1.0, 4.0] {
      var cues: [String] = []
      let snapshot: [String: Any] = ["sessionId": "cap", "indoor": false, "autoPause": true,
        "messages": ["faster": "faster", "slower": "slower"],
        "steps": [["id": "easy", "goal": "time", "amount": 300.0, "movement": "run", "primaryTarget": "pace", "maxSpeed": 2.5, "minSpeed": 2.0, "intensity": "easy"]]]
      let engine = CardioEngine(CardioEngine.fresh(snapshot), speak: { cues.append($0) })
      engine.state["countdown"] = 0.0
      for second in 0...90 {
        let fix = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 52 + Double(second) * speed / 111195, longitude: 13),
          altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: speed, timestamp: Date())
        _ = engine.location(fix, now: Double(second))
        engine.tick(Double(second))
      }
      XCTAssertEqual(cues.filter { $0 == "faster" }.count, 0)
      XCTAssertEqual(cues.filter { $0 == "slower" }.count, speed > 2.5 ? 1 : 0)
    }
  }

  func testStandingRecoveryDoesNotDisableNextRunAutoPause() {
    let snapshot: [String: Any] = ["sessionId": "rest", "indoor": false, "autoPause": true,
      "steps": [["id": "rest", "goal": "time", "amount": 15.0, "movement": "rest", "standingRecovery": true],
                ["id": "run", "goal": "time", "amount": 300.0, "movement": "run"]]]
    let engine = CardioEngine(CardioEngine.fresh(snapshot), speak: { _ in })
    engine.state["countdown"] = 0.0
    for second in 0...30 {
      let fix = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 52, longitude: 13),
        altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0, timestamp: Date())
      _ = engine.location(fix, now: Double(second))
      engine.tick(Double(second))
    }
    XCTAssertEqual(engine.state["status"] as? String, "paused")
    XCTAssertEqual((engine.state["results"] as? [[String: Any]])?.count, 1)
  }

  func testCardioTimeIntervalsRunWithoutFlutter() {
    let snapshot: [String: Any] = ["version": 1, "sessionId": "test", "indoor": true, "autoPause": true,
      "steps": [["id": "first", "goal": "time", "amount": 2.5], ["id": "second", "goal": "time", "amount": 2.5]]]
    let engine = CardioEngine(CardioEngine.fresh(snapshot), speak: { _ in })
    engine.state["countdown"] = 0.0
    for second in 0...6 { engine.tick(Double(second)) }
    XCTAssertEqual(engine.state["status"] as? String, "active")
    XCTAssertEqual(engine.state["goalReached"] as? Bool, true)
    XCTAssertEqual(engine.number("activeSeconds"), 6, accuracy: 0.001)
    XCTAssertEqual((engine.state["results"] as? [[String: Any]])?.count, 2)
  }

  func testCardioGpsLossDoesNotPauseOrAdvanceDistance() {
    let engine = CardioEngine(CardioEngine.fresh(["version": 1, "sessionId": "test", "indoor": false, "autoPause": true,
      "steps": [["id": "first", "goal": "distance", "amount": 100.0]]]), speak: { _ in })
    engine.state["countdown"] = 0.0
    for second in 0...30 { engine.tick(Double(second)) }
    XCTAssertEqual(engine.state["status"] as? String, "active")
    XCTAssertEqual(engine.state["gps"] as? String, "gpsLost")
    XCTAssertEqual(engine.number("distanceMeters"), 0)
  }

}
