import Foundation
import CoreLocation

/// Native reducer: no Dart timer, wall-clock deltas or network dependencies.
final class CardioEngine {
    var state: [String: Any]
    private let speak: (String) -> Void
    private var lastTick: Double?, stillSince: Double?, outsideSince: Double?
    private var lastCorrection = -1000.0, lastFix = -1000.0
    private var previous: (CLLocation, Double)?
    private var speeds: [(time: Double, value: Double, weight: Double)] = []
    private var positions: [(Double, Double)] = []
    private var measuredDistance = 0.0
    private var lastSample: Double?
    var steps: [[String: Any]] { state["steps"] as? [[String: Any]] ?? [] }
    var index: Int { (state["index"] as? NSNumber)?.intValue ?? 0 }
    var continuing: Bool { state["goalReached"] as? Bool == true }
    var current: [String: Any] { continuing ? ["id": "continuation", "displayName": message("continueEasy"),
        "movement": "run", "intensity": "easy", "primaryTarget": "effort"] : steps[index] }
    private func rule(_ key: String, _ fallback: Double) -> Double {
        ((state["trackingRules"] as? [String: Any])?[key] as? NSNumber)?.doubleValue ?? fallback
    }
    func number(_ key: String) -> Double { (state[key] as? NSNumber)?.doubleValue ?? 0 }
    private func amount() -> Double {
        let target = (current["routeTotalMeters"] as? NSNumber).map {
            max(0, $0.doubleValue - (number("distanceMeters") - number("stepMeters")))
        } ?? (current["amount"] as? NSNumber)?.doubleValue ?? 1
        state["stepTargetAmount"] = target
        return target
    }
    func message(_ key: String) -> String { (state["messages"] as? [String: String])?[key] ?? key }
    private func cue(_ text: String, kind: String, priority: Int = 30, unique: Bool = true) {
        guard !text.isEmpty, state["audioEnabled"] as? Bool != false else { return }
        let id = "\(state["sessionId"] as? String ?? ""):\(index):\(kind)"
        var sent = state["cueIds"] as? [String] ?? []
        if unique && sent.contains(id) { return }
        if unique { sent.append(id); state["cueIds"] = sent }
        state["audioEvent"] = ["id": id, "index": index, "priority": priority,
                               "expires": number("elapsedSeconds") + 8, "text": text]
        speak(text)
    }
    init(_ state: [String: Any], speak: @escaping (String) -> Void) { self.state = state; self.speak = speak }
    static func fresh(_ snapshot: [String: Any]) -> [String: Any] {
        snapshot.merging(["status": "active", "index": 0, "activeSeconds": 0.0, "elapsedSeconds": 0.0,
                          "distanceMeters": 0.0, "stepSeconds": 0.0, "stepMeters": 0.0, "countdown": 3.0,
                          "results": [[String: Any]](), "gps": "gpsWaiting", "sequence": -1]) { _, new in new }
    }
    func tick(_ now: Double) {
        var dt = lastTick.map { max(0, now - $0) } ?? 0
        lastTick = now
        if state["status"] as? String == "completed" { return }
        state["elapsedSeconds"] = number("elapsedSeconds") + dt
        if state["indoor"] as? Bool != true {
            let stale = now - lastFix > 15, old = state["gps"] as? String
            state["gps"] = stale ? "gpsLost" : "gpsReady"
            if stale {
                state.removeValue(forKey: "speed"); state["paceQuality"] = "uncertain"; stillSince = nil; outsideSince = nil
                if old == "gpsReady" { cue(message("gpsLost"), kind: "gpsLost", priority: 40, unique: false) }
            }
        }
        guard state["status"] as? String == "active" else { return }
        if number("countdown") > 0 {
            let waiting = number("countdown")
            state["countdown"] = max(0, number("countdown") - dt)
            dt = max(0, dt - waiting)
            if number("countdown") == 0 { previous = nil; cue(current["startCue"] as? String ?? "", kind: "start", priority: 90) }
            if dt == 0 { return }
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
        advance(deltaSeconds: dt, deltaMeters: 0)
        guard state["status"] as? String == "active", !continuing else { return }
        let distance = current["goal"] as? String == "distance"
        let progress = number(distance ? "stepMeters" : "stepSeconds")
        let amount = amount()
        if amount >= (distance ? 300 : 60) && progress >= amount / 2 && state["half"] as? Bool != true {
            state["half"] = true; cue(current["halfCue"] as? String ?? message("half"), kind: "half")
        }
        let near = distance ? 100.0 : 15.0
        if amount >= near * 3 && amount - progress <= near && state["near"] as? Bool != true {
            state["near"] = true; cue(current["nearCue"] as? String ?? message("nearEnd"), kind: "near", priority: 50)
        }
        coach(now)
    }
    func location(_ fix: CLLocation, now: Double, receivedAt: Double? = nil) -> [String: Any]? {
        let received = receivedAt ?? now
        guard state["status"] as? String != "completed", state["indoor"] as? Bool != true,
              fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= 35, abs(fix.timestamp.timeIntervalSinceNow) <= 5,
              CLLocationCoordinate2DIsValid(fix.coordinate) else { return nil }
        if received - now > 5 || now > received + 1 || (lastSample != nil && now <= lastSample!) { return nil }
        let sampleGap = lastSample.map { now - $0 } ?? 0
        let gap = previous.map { now - $0.1 } ?? 0
        let distance = previous.map { fix.distance(from: $0.0) } ?? 0
        let maximum = state["sport"] as? String == "cycling" ? 35.0 : 12.0
        if previous != nil && (gap <= 0 || (gap <= 15 && distance / gap > maximum)) { return nil }
        let reported = fix.speed.isFinite && fix.speed >= 0 && fix.speed <= maximum ? fix.speed : nil
        let resolved = previous == nil || gap > 15 || distance >= max(3, max(fix.horizontalAccuracy, previous?.0.horizontalAccuracy ?? 0) / 2)
        if resolved { previous = (fix, now) }
        lastFix = now
        lastSample = now
        let measured = reported ?? (gap > 0 && gap <= 15 ? distance / gap : 0)
        if sampleGap > 15 { speeds = []; positions = [] }
        let acceptedDistance = resolved && gap > 0 && gap <= 15 && measured >= 0.35 ? distance : 0
        measuredDistance += acceptedDistance
        let uncertainty = fix.speedAccuracy >= 0 && fix.speedAccuracy.isFinite ? fix.speedAccuracy : nil
        updatePace(now, dt: sampleGap, reported: reported, uncertainty: uncertainty, accuracy: fix.horizontalAccuracy)
        state["motionSpeed"] = measured
        state["gps"] = "gpsReady"
        let wasActive = state["status"] as? String == "active"
        if state["status"] as? String == "paused" && state["autoPaused"] as? Bool == true && measured > 0.7 { resume() }
        let active = wasActive && state["status"] as? String == "active" && number("countdown") == 0
        if active && acceptedDistance > 0 {
            let currentSeconds = min(gap, number("stepSeconds"))
            var pastSeconds = gap - currentSeconds
            var results = state["results"] as? [[String: Any]] ?? []
            for i in results.indices.reversed() {
                if pastSeconds <= 0 { break }
                let seconds = min(pastSeconds, (results[i]["seconds"] as? NSNumber)?.doubleValue ?? 0)
                results[i]["meters"] = ((results[i]["meters"] as? NSNumber)?.doubleValue ?? 0) + distance * seconds / gap
                pastSeconds -= seconds
            }
            state["results"] = results
            let currentDistance = pastSeconds == gap ? distance : distance * currentSeconds / gap
            state["distanceMeters"] = number("distanceMeters") + distance
            state["stepMeters"] = number("stepMeters") + currentDistance
            advance(deltaSeconds: currentSeconds, deltaMeters: currentDistance)
        }
        let seq = (state["sequence"] as? Int ?? -1) + 1; state["sequence"] = seq
        return ["sequence": seq, "timestamp": Int(fix.timestamp.timeIntervalSince1970 * 1000), "latitude": fix.coordinate.latitude,
                "longitude": fix.coordinate.longitude, "accuracy": fix.horizontalAccuracy, "speed": measured, "source": "phone_gps", "active": active, "gap": gap > 15,
                "measurementVersion": 2, "measuredAt": now, "receivedAt": received,
                "speedAccuracy": uncertainty.map { $0 as Any } ?? NSNull(), "acceptedMeters": acceptedDistance,
                "paceQuality": state["paceQuality"] ?? "uncertain"]
    }
    private func updatePace(_ now: Double, dt: Double, reported: Double?, uncertainty: Double?, accuracy: Double) {
        let window = rule("paceWindowSeconds", 15)
        let good = reported != nil && uncertainty != nil && uncertainty!.isFinite &&
            uncertainty! >= 0 && uncertainty! <= max(0.2, reported! * 0.15)
        if good { speeds.append((now, reported!, min(5, max(0.01, dt)))) }
        speeds.removeAll { now - $0.time > window }
        positions.append((now, measuredDistance))
        positions.removeAll { now - $0.0 > rule("positionWindowSeconds", 30) }
        let span = now - positions[0].0, meters = measuredDistance - positions[0].1
        let positional: Double? = span >= 20 && accuracy <= 15 && meters >= max(10, accuracy * 4) ? meters / span : nil
        let weight = speeds.reduce(0) { $0 + $1.weight }
        var estimate: Double?
        if good && weight >= min(5, window) {
            var accumulated = 0.0
            estimate = speeds.sorted { $0.value < $1.value }.first {
                accumulated += $0.weight; return accumulated >= weight / 2
            }?.value
        } else { estimate = positional }
        let inconsistent = estimate != nil && good && positional != nil &&
            abs(estimate! - positional!) > max(0.5, estimate! * 0.3)
        state["paceQuality"] = estimate != nil && !inconsistent ? "reliable" : "uncertain"
        if let estimate = estimate, !inconsistent { state["speed"] = estimate }
        else { state.removeValue(forKey: "speed") }
    }
    private func coach(_ now: Double) {
        guard !continuing, number("stepSeconds") >= rule("paceGraceSeconds", 30), state["gps"] as? String == "gpsReady",
              state["paceQuality"] as? String == "reliable", current["primaryTarget"] as? String == "pace" else { outsideSince = nil; return }
        let low = current["minSpeed"] as? Double, high = current["maxSpeed"] as? Double
        let speed = number("speed")
        if speed <= 0.35 { outsideSince = nil; return }
        let tolerance = rule("paceToleranceSecondsPerKm", 60)
        let fast = high.map { $0 > 0 && 1000 / speed < 1000 / $0 - tolerance } ?? false
        let slow = !["easy", "recovery"].contains(current["intensity"] as? String ?? "") && (low.map { $0 > 0 && 1000 / speed > 1000 / $0 + tolerance } ?? false)
        if !fast && !slow { outsideSince = nil; return }
        if outsideSince == nil { outsideSince = now }
        if now - outsideSince! >= rule("paceSustainedSeconds", 20) && now - lastCorrection >= rule("paceCooldownSeconds", 90) {
            cue(message(fast ? "slower" : "faster"), kind: "pace", unique: false); lastCorrection = now; outsideSince = nil
        }
    }
    private func record(partial: Bool = false) {
        var results = state["results"] as? [[String: Any]] ?? []
        results.append(["id": current["id"] ?? "", "name": current["displayName"] ?? "", "index": index,
                        "seconds": number("stepSeconds"), "meters": number("stepMeters"), "partial": partial && !continuing, "continuation": continuing])
        state["results"] = results
    }
    private func advance(deltaSeconds: Double, deltaMeters: Double) {
        var intervalSeconds = deltaSeconds, intervalMeters = deltaMeters
        while state["status"] as? String == "active" && !continuing {
            let step = current
            let progress = number(step["goal"] as? String == "distance" ? "stepMeters" : "stepSeconds")
            let amount = amount()
            if progress < amount { return }
            let delta = step["goal"] as? String == "distance" ? intervalMeters : intervalSeconds
            let remaining = delta > 0 ? min(1, max(0, (progress - amount) / delta)) : 0
            let carrySeconds = intervalSeconds * remaining, carryMeters = intervalMeters * remaining
            state["stepSeconds"] = number("stepSeconds") - carrySeconds; state["stepMeters"] = number("stepMeters") - carryMeters
            record()
            if index + 1 < steps.count { cue(step["endCue"] as? String ?? message("completed"), kind: "end", priority: 80) }
            if number("stepSeconds") > 0 && number("stepMeters") > 0 {
                let unit = (state["unitMeters"] as? NSNumber)?.doubleValue ?? 1000
                if state["sport"] as? String == "cycling" {
                    let speed = number("stepMeters") / number("stepSeconds") * 3600 / unit
                    cue("\(message("average")): \(String(format: "%.1f", locale: Locale(identifier: state["locale"] as? String ?? "en"), speed)) \(unit > 1500 ? "mph" : "km/h")", kind: "average")
                } else {
                    let seconds = Int((unit * number("stepSeconds") / number("stepMeters")).rounded())
                    let de = (state["locale"] as? String ?? "en").hasPrefix("de")
                    cue("\(message("average")): \(seconds / 60) \(de ? "Minuten" : "minutes") \(seconds % 60) \(de ? "Sekunden pro" : "seconds per") \(unit > 1500 ? (de ? "Meile" : "mile") : (de ? "Kilometer" : "kilometre"))", kind: "average")
                }
            }
            if index + 1 >= steps.count {
                state["goalReached"] = true; state["plannedHadPause"] = state["hadPause"] as? Bool ?? false
                state["index"] = steps.count; state["stepSeconds"] = carrySeconds; state["stepMeters"] = carryMeters
                outsideSince = nil; cue(message("goalReached"), kind: "goalReached", priority: 100); return
            }
            state["index"] = index + 1; state["stepSeconds"] = carrySeconds; state["stepMeters"] = carryMeters
            state["half"] = false; state["near"] = false; stillSince = nil; outsideSince = nil
            intervalSeconds = carrySeconds; intervalMeters = carryMeters
            cue(current["startCue"] as? String ?? "", kind: "start", priority: 90)
        }
    }
    func pause(automatic: Bool = false) {
        guard state["status"] as? String == "active" else { return }
        state["status"] = "paused"; state["autoPaused"] = automatic; state["hadPause"] = true; previous = nil
        cue(message("paused"), kind: "paused", priority: 100, unique: false)
    }
    func resume() {
        guard state["status"] as? String == "paused" else { return }
        state["status"] = "active"; state["autoPaused"] = false
        stillSince = nil; previous = nil; speeds = []; positions = []; lastSample = nil
        state.removeValue(forKey: "speed"); state["paceQuality"] = "uncertain"; outsideSince = nil; lastTick = nil
        cue(message("resume"), kind: "resume", priority: 100, unique: false)
    }
    func finish() {
        if state["status"] as? String == "completed" { return }
        if number("stepSeconds") > 0 || number("stepMeters") > 0 { record(partial: true) }
        complete()
    }
    private func complete() {
        state["status"] = "completed"; state["endedAt"] = Int(Date().timeIntervalSince1970 * 1000)
        cue(message("completed"), kind: "completed", priority: 100)
    }
}
