import Foundation
import Flutter
import CoreLocation
import AVFoundation
import HealthKit
import UIKit

final class CardioRecorder: NSObject, CardioHostApi, CLLocationManagerDelegate, AVSpeechSynthesizerDelegate {
    private let locations = CLLocationManager(), speech = AVSpeechSynthesizer(), health = HKHealthStore()
    private var engine: CardioEngine?, ticker: Timer?
    private var permissionReply: ((Result<String, Error>) -> Void)?
    private var preparedLocale = "en"
    private var readyResult: String { AVSpeechSynthesisVoice(language: preparedLocale) == nil ? "ready_silent" : "ready" }
    private var session: AnyObject?
    private var sampleOffset: UInt64 = 0, sampleDelivered: Int64 = -1
    private var sampleSession: String?
    private var journal: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("cardio-session.json") }
    private var samplesURL: URL { journal.deletingLastPathComponent().appendingPathComponent("cardio-samples.jsonl") }
    override init() {
        super.init(); locations.delegate = self; speech.delegate = self
        // Only Trainy's explicitly enabled backup may upload training/route data.
        for kind in [FileManager.SearchPathDirectory.documentDirectory, .applicationSupportDirectory] {
            if let directory = FileManager.default.urls(for: kind, in: .userDomainMask).first {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? excludeBackup(directory)
            }
        }
        locations.activityType = .fitness; locations.desiredAccuracy = kCLLocationAccuracyBest
        locations.distanceFilter = kCLDistanceFilterNone; locations.pausesLocationUpdatesAutomatically = false
        if let data = try? Data(contentsOf: journal), var value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if value["status"] as? String != "completed" { value["status"] = "paused"; value["autoPaused"] = false; value["recovered"] = true }
            value["sequence"] = (try? reconcileSamples(checkpoint: value["sequence"] as? Int64 ?? -1)) ?? value["sequence"]
            engine = CardioEngine(value, speak: { [weak self] in self?.say($0) })
        }
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    private var supportsIndoorBackground: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { return HKHealthStore.isHealthDataAvailable() }
        #endif
        return false
    }
    func capabilities() throws -> String { try encode(["available": true, "indoorBackground": supportsIndoorBackground]) }
    func prepare(outdoor: Bool, locale: String, completion: @escaping (Result<String, Error>) -> Void) {
        preparedLocale = locale
        if !outdoor {
            if supportsIndoorBackground {
                health.requestAuthorization(toShare: [HKObjectType.workoutType()], read: []) { [weak self] _, error in
                    DispatchQueue.main.async {
                        if let error = error { completion(.failure(error)); return }
                        completion(.success(self?.health.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized ? (self?.readyResult ?? "ready_silent") : "denied"))
                    }
                }
            } else { completion(.success(readyResult)) }
            return
        }
        guard permissionReply == nil else { completion(.failure(failure("permission_pending"))); return }
        if locations.authorizationStatus == .notDetermined { permissionReply = completion; locations.requestWhenInUseAuthorization() }
        else { completion(.success(locationAllowed ? readyResult : "denied")) }
    }
    private var locationAllowed: Bool { [.authorizedAlways, .authorizedWhenInUse].contains(locations.authorizationStatus) && locations.accuracyAuthorization == .fullAccuracy }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus != .notDetermined, let reply = permissionReply { permissionReply = nil; reply(.success(locationAllowed ? readyResult : "denied")) }
        if !locationAllowed && engine?.state["indoor"] as? Bool != true { engine?.state["gps"] = "gpsLost" }
    }
    func start(snapshotJson: String) throws {
        guard engine == nil else { throw failure("unacknowledged_session") }
        guard let bytes = snapshotJson.data(using: .utf8), let snapshot = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              snapshot["version"] as? Int == 1, let steps = snapshot["steps"] as? [[String: Any]], !steps.isEmpty else { throw failure("invalid_snapshot") }
        if snapshot["indoor"] as? Bool != true && !locationAllowed { throw failure("location_denied") }
        engine = CardioEngine(CardioEngine.fresh(snapshot), speak: { [weak self] in self?.say($0) })
        do { try persist(); try beginSources(); } catch { engine?.pause(); try? persist(); throw error }
    }
    private func beginSources() throws {
        guard let engine = engine else { return }
        if engine.state["indoor"] as? Bool != true {
            locations.allowsBackgroundLocationUpdates = true; locations.showsBackgroundLocationIndicator = true
            locations.startUpdatingLocation()
        } else {
            #if compiler(>=6.2)
            if #available(iOS 26.0, *), supportsIndoorBackground, session == nil {
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = engine.state["sport"] as? String == "cycling" ? .cycling : .running
                configuration.locationType = .indoor
                let workout = try HKWorkoutSession(healthStore: health, configuration: configuration)
                workout.delegate = self; session = workout; workout.startActivity(with: Date())
            }
            #endif
        }
        ticker?.invalidate()
        ticker = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(ticker!, forMode: .common)
        UIApplication.shared.isIdleTimerDisabled = engine.state["indoor"] as? Bool == true && !supportsIndoorBackground
    }
    private func tick() {
        engine?.tick(ProcessInfo.processInfo.systemUptime)
        do { try persist() } catch { engine?.pause(); engine?.state["storageError"] = true }
        if engine?.state["status"] as? String == "completed" { stopSources() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations updates: [CLLocation]) {
        let received = ProcessInfo.processInfo.systemUptime, wall = Date()
        for location in updates.sorted(by: { $0.timestamp < $1.timestamp }) {
            let measured = received + location.timestamp.timeIntervalSince(wall)
            guard let sample = engine?.location(location, now: measured, receivedAt: received) else { continue }
            do {
                var data = try JSONSerialization.data(withJSONObject: sample); data.append(0x0A)
                if !FileManager.default.fileExists(atPath: samplesURL.path) { try Data().write(to: samplesURL, options: .completeFileProtectionUntilFirstUserAuthentication); try excludeBackup(samplesURL) }
                let file = try FileHandle(forWritingTo: samplesURL); defer { try? file.close() }
                try file.seekToEnd(); try file.write(contentsOf: data)
            } catch { engine?.pause(); engine?.state["storageError"] = true }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { engine?.state["gps"] = "gpsLost" }
    private func say(_ text: String) {
        guard let event = engine?.state["audioEvent"] as? [String: Any],
              let priority = event["priority"] as? Int else { return }
        if priority >= 80 { speech.stopSpeaking(at: .immediate) }
        else if speech.isSpeaking { return }
        guard !text.isEmpty else { return }
        let language = engine?.state["locale"] as? String ?? "en"
        guard let voice = AVSpeechSynthesisVoice(language: language) else { engine?.state["audioUnavailable"] = true; return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let utterance = AVSpeechUtterance(string: text); utterance.voice = voice; speech.speak(utterance)
        } catch { engine?.state["audioUnavailable"] = true }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if !synthesizer.isSpeaking { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
    func state() throws -> String? { guard let value = engine?.state else { return nil }; return try encode(value) }
    func recover(runtimeJson: String) throws {
        guard engine == nil, let bytes = runtimeJson.data(using: .utf8),
              var value = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              value["version"] as? Int == 1, let steps = value["steps"] as? [[String: Any]], !steps.isEmpty else { throw failure("invalid_recovery") }
        value["status"] = "paused"; value["autoPaused"] = false; value["recovered"] = true
        value["sequence"] = try reconcileSamples(checkpoint: value["sequence"] as? Int64 ?? -1)
        engine = CardioEngine(value, speak: { [weak self] in self?.say($0) }); try persist()
    }
    func discard() throws {
        stopSources(); engine = nil; speech.stopSpeaking(at: .immediate)
        for url in [journal, samplesURL] where FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    func samples(afterSequence: Int64) throws -> String {
        guard FileManager.default.fileExists(atPath: samplesURL.path) else { return "[]" }
        // Cursor reads only new data. A retried/uncommitted page is replayed safely.
        let file = try FileHandle(forReadingFrom: samplesURL); defer { try? file.close() }
        let sessionId = engine?.state["sessionId"] as? String
        let size = try file.seekToEnd()
        if sampleSession != sessionId || afterSequence != sampleDelivered || sampleOffset > size { sampleOffset = 0 }
        sampleSession = sessionId
        try file.seek(toOffset: sampleOffset)
        var carry = Data(), values = [[String: Any]]()
        while values.count < 1000, let chunk = try file.read(upToCount: 65536), !chunk.isEmpty {
            carry.append(chunk)
            while values.count < 1000, let end = carry.firstIndex(of: 0x0A) {
                let line = Data(carry[..<end]); sampleOffset += UInt64(line.count + 1); carry.removeSubrange(...end)
                if let sample = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any], let sequence = sample["sequence"] as? Int64, sequence > afterSequence { values.append(sample) }
            }
            if carry.count > 65536 { throw failure("invalid_sensor_row") }
        }
        sampleDelivered = values.last?["sequence"] as? Int64 ?? afterSequence
        return try encode(values)
    }
    private func reconcileSamples(checkpoint: Int64) throws -> Int64 {
        guard FileManager.default.fileExists(atPath: samplesURL.path) else { return checkpoint }
        let file = try FileHandle(forUpdating: samplesURL); defer { try? file.close() }
        let length = try file.seekToEnd(), start = length > 65536 ? length - 65536 : 0
        try file.seek(toOffset: start)
        let tail = try file.read(upToCount: 65536) ?? Data()
        guard let end = tail.lastIndex(of: 0x0A) else { try file.truncate(atOffset: start); return checkpoint }
        try file.truncate(atOffset: start + UInt64(end + 1))
        return tail.prefix(end + 1).split(separator: 0x0A).reduce(checkpoint) { sequence, line in
            let value = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
            return max(sequence, value?["sequence"] as? Int64 ?? -1)
        }
    }
    func pause() throws { engine?.pause(); try persist() }
    func setAudioEnabled(enabled: Bool) throws {
        engine?.state["audioEnabled"] = enabled
        if !enabled { speech.stopSpeaking(at: .immediate) }
        try persist()
    }
    func resume() throws { try beginSources(); engine?.resume(); try persist() }
    func finish() throws { engine?.finish(); try persist(); stopSources() }
    func acknowledge(sessionId: String) throws {
        guard engine?.state["sessionId"] as? String == sessionId, engine?.state["status"] as? String == "completed" else { throw failure("invalid_acknowledgement") }
        stopSources(); try FileManager.default.removeItem(at: journal)
        if FileManager.default.fileExists(atPath: samplesURL.path) { try FileManager.default.removeItem(at: samplesURL) }
        engine = nil
    }
    func openSettings() throws { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
    @objc private func background() {
        if engine?.state["indoor"] as? Bool == true && !supportsIndoorBackground { engine?.pause(); try? persist() }
    }
    private func stopSources() {
        ticker?.invalidate(); ticker = nil; locations.stopUpdatingLocation(); UIApplication.shared.isIdleTimerDisabled = false
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), let workout = session as? HKWorkoutSession { workout.end(); session = nil }
        #endif
    }
    private func persist() throws {
        guard let state = engine?.state else { return }
        try FileManager.default.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: state).write(to: journal, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try excludeBackup(journal)
    }
    private func excludeBackup(_ file: URL) throws { var url = file; var values = URLResourceValues(); values.isExcludedFromBackup = true; try url.setResourceValues(values) }
    private func encode(_ value: Any) throws -> String { String(data: try JSONSerialization.data(withJSONObject: value), encoding: .utf8)! }
    private func failure(_ code: String) -> NSError { NSError(domain: "trainy.cardio", code: 1, userInfo: [NSLocalizedDescriptionKey: code]) }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
extension CardioRecorder: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.engine?.pause(); self?.engine?.state["backgroundError"] = true; try? self?.persist() }
    }
}
#endif
