//
//  PhoneSync.swift
//  FitnessWorkouts (iPhone)
//
//  Reads the full running history on the iPhone (which, unlike the watch, keeps all Health
//  data — every indoor, outdoor and third-party run) and sends it to the watch.
//

import Foundation
import HealthKit
import WatchConnectivity

enum PhoneSync {
    /// Fetches the last 8 weeks of runs, caches them and pushes them to the watch.
    @discardableResult
    static func fetchAndPush() async throws -> [RunSummary] {
        let service = RunningDataService()
        let runs = try await service.fetchRuns(from: MileageCalculator.windowStart())
        MileageStore.saveRuns(runs)
        PhoneSessionManager.shared.push(runs)
        return runs
    }
}

// MARK: - WatchConnectivity

final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    private(set) var lastPushDate: Date?
    /// Runs waiting to be sent because the session wasn't activated yet.
    private var pendingRuns: [RunSummary]?
    private(set) var lastPushResult = "Nothing sent yet"

    /// Shown on the Sync Status section of the iPhone app.
    var statusLines: [SyncStatusLine] {
        guard WCSession.isSupported() else {
            return [SyncStatusLine(label: "Watch connection", value: "Not supported on this device")]
        }
        let s = WCSession.default
        return [
            SyncStatusLine(label: "Session", value: s.activationState.label),
            SyncStatusLine(label: "Watch paired", value: s.isPaired ? "Yes" : "No"),
            SyncStatusLine(label: "Watch app installed", value: s.isWatchAppInstalled ? "Yes" : "No"),
            SyncStatusLine(label: "Watch reachable now", value: s.isReachable ? "Yes" : "No"),
            SyncStatusLine(label: "Widget on watch face", value: s.isComplicationEnabled ? "Yes" : "No"),
            SyncStatusLine(label: "Last send", value: lastPushResult),
        ]
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    var isWatchAppInstalled: Bool {
        WCSession.isSupported() && WCSession.default.isPaired && WCSession.default.isWatchAppInstalled
    }

    /// Sends the runs to the watch. `updateApplicationContext` delivers the latest copy whenever the
    /// watch app next runs; a complication transfer (when the widget is on the watch face) also wakes
    /// the watch app in the background so the widget updates promptly.
    func push(_ runs: [RunSummary]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            // Activation is asynchronous and usually still in progress right after launch.
            pendingRuns = runs
            lastPushResult = "Waiting for watch connection (\(session.activationState.label))"
            return
        }
        guard session.isPaired else {
            lastPushResult = "Not sent: no paired Apple Watch"
            return
        }
        guard session.isWatchAppInstalled else {
            lastPushResult = "Not sent: iPhone doesn't see the watch app as installed"
            return
        }
        pendingRuns = nil

        let payload = RunPayload.encode(runs)
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        do {
            try session.updateApplicationContext(payload)
            lastPushResult = "Sent \(runs.count) runs at \(time)"
        } catch {
            // Fall back to a queued transfer, which is delivered even if the context update fails.
            session.transferUserInfo(payload)
            lastPushResult = "Context failed (\(error.localizedDescription)); queued transfer at \(time)"
        }
        if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(payload)
        }
        lastPushDate = .now
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            let session = PhoneSessionManager.shared
            if let pending = session.pendingRuns {
                session.push(pending)
            } else {
                let cached = MileageStore.loadRuns()
                if !cached.isEmpty { session.push(cached) }
            }
        }
    }

    /// Fires when the watch app is installed or the widget is added to / removed from the face.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        guard session.isWatchAppInstalled else { return }
        Task { @MainActor in
            let cached = MileageStore.loadRuns()
            if !cached.isEmpty { PhoneSessionManager.shared.push(cached) }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a newly paired watch can connect.
        session.activate()
    }

    /// The watch app asks for fresh history when it opens (this can launch the iPhone app in the background).
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[RunPayload.requestKey] != nil else {
            replyHandler([:])
            return
        }
        Task { @MainActor in
            let runs = (try? await PhoneSync.fetchAndPush()) ?? MileageStore.loadRuns()
            replyHandler(RunPayload.encode(runs))
        }
    }
}

// MARK: - HealthKit background delivery

/// Wakes the iPhone app whenever a workout is saved to Health (from the watch, the iPhone, or any
/// other app or device) so the new run reaches the watch without opening the app.
enum HealthBackgroundSync {
    private static let store = HKHealthStore()
    private static var started = false

    static func start() {
        guard HKHealthStore.isHealthDataAvailable(), !started else { return }
        started = true

        let workoutType = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            Task { @MainActor in
                _ = try? await PhoneSync.fetchAndPush()
                completionHandler()
            }
        }
        store.execute(query)
        store.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }
}

extension WCSessionActivationState {
    var label: String {
        switch self {
        case .activated: "Activated"
        case .inactive: "Inactive"
        case .notActivated: "Not activated"
        @unknown default: "Unknown"
        }
    }
}
