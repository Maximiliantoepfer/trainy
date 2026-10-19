import Flutter
import UIKit
import XCTest
import CoreLocation
@testable import Runner

class RunnerTests: XCTestCase {

  func testEasyPaceCapNeverRequestsAcceleration() {
    for speed in [1.0, 4.0] {
      var cues: [String] = []
      let snapshot: [String: Any] = ["sessionId": "cap", "indoor": false, "autoPause": true,
        "messages": ["faster": "faster", "slower": "slower"],
        "steps": [["id": "easy", "goal": "time", "amount": 300.0, "movement": "run", "primaryTarget": "pace", "maxSpeed": 2.5]]]
      let engine = CardioEngine(CardioEngine.fresh(snapshot), speak: { cues.append($0) })
      engine.state["countdown"] = 0.0
      for second in 0...90 {
        let fix = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 52 + Double(second) * 0.000009, longitude: 13),
          altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: speed, timestamp: Date())
        _ = engine.location(fix, now: Double(second))
        engine.tick(Double(second))
      }
      XCTAssertEqual(cues.filter { $0 == "faster" }.count, 0)
      XCTAssertEqual(cues.filter { $0 == "slower" }.count, speed > 2.5 ? 2 : 0)
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
    XCTAssertEqual(engine.state["status"] as? String, "completed")
    XCTAssertEqual(engine.number("activeSeconds"), 5, accuracy: 0.001)
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
