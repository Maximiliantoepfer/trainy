import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
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
