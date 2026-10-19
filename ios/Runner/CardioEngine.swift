import Foundation
import CoreLocation

/// Native reducer: no Dart timer, wall-clock deltas or network dependencies.
final class CardioEngine {
    var state: [String: Any]
    private let speak: (String) -> Void
    private var lastTick: Double?, stillSince: Double?, outsideSince: Double?
    private var lastCorrection = -1000.0, lastFix = -1000.0
    private var previous: (CLLocation, Double)?
    private var speeds: [(Double, Double)] = []
    var steps: [[String: Any]] { state["steps"] as? [[String: Any]] ?? [] }
    var index: Int { (state["index"] as? NSNumber)?.intValue ?? 0 }
    var current: [String: Any] { steps[index] }
    func number(_ key: String) -> Double { (state[key] as? NSNumber)?.doubleValue ?? 0 }
    func message(_ key: String) -> String { (state["messages"] as? [String: String])?[key] ?? key }
    init(_ state: [String: Any], speak: @escaping (String) -> Void) { self.state = state; self.speak = speak }
    static func fresh(_ snapshot: [String: Any]) -> [String: Any] {
        snapshot.merging(["status": "active", "index": 0, "activeSeconds": 0.0, "elapsedSeconds": 0.0,
                          "distanceMeters": 0.0, "stepSeconds": 0.0, "stepMeters": 0.0, "countdown": 3.0,
                          "results": [[String: Any]](), "gps": "gpsWaiting", "sequence": -1]) { _, new in new }
    }
    func tick(_ now: Double) {
        let dt = lastTick.map { min(5, max(0, now - $0)) } ?? 0
        lastTick = now
        if state["status"] as? String == "completed" { return }
        state["elapsedSeconds"] = number("elapsedSeconds") + dt
        if state["indoor"] as? Bool != true {
            let stale = now - lastFix > 15, old = state["gps"] as? String
            state["gps"] = stale ? "gpsLost" : "gpsReady"
            if stale {
                state.removeValue(forKey: "speed"); stillSince = nil; outsideSince = nil
                if old == "gpsReady" { speak(message("gpsLost")) }
            }
        }
        guard state["status"] as? String == "active" else { return }
        if number("countdown") > 0 {
            state["countdown"] = max(0, number("countdown") - dt)
            if number("countdown") == 0 { speak(current["startCue"] as? String ?? "") }
            return
        }
        state["activeSeconds"] = number("activeSeconds") + dt
        if state["gps"] as? String == "gpsReady" && state["indoor"] as? Bool != true { state["gpsCoveredSeconds"] = number("gpsCoveredSeconds") + dt }
        state["stepSeconds"] = number("stepSeconds") + dt
        if state["autoPause"] as? Bool == true && state["indoor"] as? Bool != true &&
            current["standingRecovery"] as? Bool != true && !["walk", "rest"].contains(current["movement"] as? String ?? "") && state["gps"] as? String == "gpsReady" {
            if number("motionSpeed") < 0.35 {
                if stillSince == nil { stillSince = now }
                if now - stillSince! >= 10 { pause(automatic: true); return }
            } else { stillSince = nil }
        }
        advance()
        guard state["status"] as? String == "active" else { return }
        let distance = current["goal"] as? String == "distance"
        let progress = number(distance ? "stepMeters" : "stepSeconds")
        let amount = (current["amount"] as? NSNumber)?.doubleValue ?? 1
        if amount >= (distance ? 300 : 60) && progress >= amount / 2 && state["half"] as? Bool != true {
            state["half"] = true; speak(current["halfCue"] as? String ?? message("half"))
        }
        let near = distance ? 100.0 : 15.0
        if amount >= near * 3 && amount - progress <= near && state["near"] as? Bool != true {
            state["near"] = true; speak(current["nearCue"] as? String ?? message("nearEnd"))
        }
        coach(now)
    }
    func location(_ fix: CLLocation, now: Double) -> [String: Any]? {
        guard state["status"] as? String != "completed", state["indoor"] as? Bool != true,
              fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= 35, abs(fix.timestamp.timeIntervalSinceNow) <= 5,
              CLLocationCoordinate2DIsValid(fix.coordinate) else { return nil }
        let gap = previous.map { now - $0.1 } ?? 0
        let distance = previous.map { fix.distance(from: $0.0) } ?? 0
        let maximum = state["sport"] as? String == "cycling" ? 35.0 : 12.0
        if previous != nil && (gap <= 0 || (gap <= 15 && distance / gap > maximum)) { return nil }
        previous = (fix, now); lastFix = now
        let measured = fix.speed >= 0 && fix.speed <= maximum ? fix.speed :
            (gap > 0 && gap <= 15 && distance > max(3, fix.horizontalAccuracy / 2) ? distance / gap : 0)
        speeds.append((now, measured)); speeds.removeAll { now - $0.0 > 15 }
        state["motionSpeed"] = measured
        state["speed"] = speeds.map { $0.1 }.reduce(0, +) / Double(speeds.count); state["gps"] = "gpsReady"
        let wasActive = state["status"] as? String == "active"
        if state["status"] as? String == "paused" && state["autoPaused"] as? Bool == true && measured > 0.7 { resume() }
        if wasActive && state["status"] as? String == "active" && number("countdown") == 0 && gap > 0 && gap <= 15 && measured >= 0.35 {
            state["distanceMeters"] = number("distanceMeters") + distance
            state["stepMeters"] = number("stepMeters") + distance
        }
        let seq = (state["sequence"] as? Int ?? -1) + 1; state["sequence"] = seq
        return ["sequence": seq, "timestamp": Int(fix.timestamp.timeIntervalSince1970 * 1000), "latitude": fix.coordinate.latitude,
                "longitude": fix.coordinate.longitude, "accuracy": fix.horizontalAccuracy, "speed": measured, "source": "phone_gps"]
    }
    private func coach(_ now: Double) {
        guard number("stepSeconds") >= 20, state["gps"] as? String == "gpsReady", current["primaryTarget"] as? String == "pace",
              let low = current["minSpeed"] as? Double, let high = current["maxSpeed"] as? Double, low > 0, high > 0 else { return }
        let speed = number("speed")
        if speed <= 0.35 { outsideSince = nil; return }
        let fast = 1000 / speed < 1000 / high - 20, slow = 1000 / speed > 1000 / low + 20
        if !fast && !slow { outsideSince = nil; return }
        if outsideSince == nil { outsideSince = now }
        if now - outsideSince! >= 10 && now - lastCorrection >= 45 {
            speak(message(fast ? "slower" : "faster")); lastCorrection = now; outsideSince = nil
        }
    }
    private func record(partial: Bool = false) {
        var results = state["results"] as? [[String: Any]] ?? []
        results.append(["id": current["id"] ?? "", "name": current["displayName"] ?? "", "index": index,
                        "seconds": number("stepSeconds"), "meters": number("stepMeters"), "partial": partial])
        state["results"] = results
    }
    private func advance() {
        while state["status"] as? String == "active" {
            let step = current
            let progress = number(step["goal"] as? String == "distance" ? "stepMeters" : "stepSeconds")
            let amount = (step["amount"] as? NSNumber)?.doubleValue ?? 1
            if progress < amount { return }
            let fraction = min(1, max(0, amount / progress))
            let carrySeconds = number("stepSeconds") * (1 - fraction), carryMeters = number("stepMeters") * (1 - fraction)
            state["stepSeconds"] = number("stepSeconds") - carrySeconds; state["stepMeters"] = number("stepMeters") - carryMeters
            record(); speak(step["endCue"] as? String ?? message("completed"))
            if number("stepSeconds") > 0 && number("stepMeters") > 0 {
                let unit = (state["unitMeters"] as? NSNumber)?.doubleValue ?? 1000
                if state["sport"] as? String == "cycling" {
                    let speed = number("stepMeters") / number("stepSeconds") * 3600 / unit
                    speak("\(message("average")): \(String(format: "%.1f", locale: Locale(identifier: state["locale"] as? String ?? "en"), speed)) \(unit > 1500 ? "mph" : "km/h")")
                } else {
                    let seconds = Int((unit * number("stepSeconds") / number("stepMeters")).rounded())
                    speak("\(message("average")): \(seconds / 60):\(String(format: "%02d", seconds % 60)) \(unit > 1500 ? "/mi" : "/km")")
                }
            }
            if index + 1 >= steps.count {
                state["activeSeconds"] = max(0, number("activeSeconds") - carrySeconds)
                state["distanceMeters"] = max(0, number("distanceMeters") - carryMeters); complete(); return
            }
            state["index"] = index + 1; state["stepSeconds"] = carrySeconds; state["stepMeters"] = carryMeters
            state["half"] = false; state["near"] = false; stillSince = nil; outsideSince = nil
            speak(current["startCue"] as? String ?? "")
        }
    }
    func pause(automatic: Bool = false) {
        guard state["status"] as? String == "active" else { return }
        state["status"] = "paused"; state["autoPaused"] = automatic; speak(message("paused"))
    }
    func resume() {
        guard state["status"] as? String == "paused" else { return }
        state["status"] = "active"; state["autoPaused"] = false
        stillSince = nil; previous = nil; speeds = []; outsideSince = nil; lastTick = nil; speak(message("resume"))
    }
    func finish() {
        if state["status"] as? String == "completed" { return }
        if number("stepSeconds") > 0 || number("stepMeters") > 0 { record(partial: true) }
        complete()
    }
    private func complete() {
        state["status"] = "completed"; state["endedAt"] = Int(Date().timeIntervalSince1970 * 1000); speak(message("completed"))
    }
}
