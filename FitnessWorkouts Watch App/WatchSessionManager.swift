//
//  WatchSessionManager.swift
//  FitnessWorkouts Watch App
//
//  Receives the full run history from the iPhone app. The watch's own HealthKit store only
//  keeps about a week of data, so older weeks (and runs recorded on other devices) come from
//  the phone.
//

import Foundation
import WatchConnectivity
import WidgetKit

final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    nonisolated static let didReceiveRuns = Notification.Name("WatchSessionManager.didReceiveRuns")

    private(set) var lastRequestResult = "Not requested yet"

    var statusLines: [SyncStatusLine] {
        guard WCSession.isSupported() else {
            return [SyncStatusLine(label: "Connection", value: "Not supported")]
        }
        let s = WCSession.default
        let received = MileageStore.lastPhoneSyncDate
            .map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never"
        return [
            SyncStatusLine(label: "Session", value: s.activationState.label),
            SyncStatusLine(label: "iPhone app installed", value: s.isCompanionAppInstalled ? "Yes" : "No"),
            SyncStatusLine(label: "iPhone reachable", value: s.isReachable ? "Yes" : "No"),
            SyncStatusLine(label: "History received", value: received),
            SyncStatusLine(label: "Runs from iPhone", value: "\(MileageStore.loadPhoneRuns().count)"),
            SyncStatusLine(label: "Last request", value: lastRequestResult),
        ]
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Asks the iPhone for fresh history if it is reachable right now.
    /// Returns true when new data arrived.
    func requestRunsFromPhone() async -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        // Activation is asynchronous; give it a few seconds right after launch.
        for _ in 0..<20 where session.activationState != .activated {
            try? await Task.sleep(for: .milliseconds(150))
        }
        guard session.activationState == .activated else {
            lastRequestResult = "Session \(session.activationState.label)"
            return false
        }
        guard session.isReachable else {
            lastRequestResult = "iPhone not reachable"
            return false
        }

        let result: String = await withCheckedContinuation { continuation in
            session.sendMessage([RunPayload.requestKey: true]) { reply in
                if Self.store(reply) {
                    let count = RunPayload.decode(reply)?.runs.count ?? 0
                    continuation.resume(returning: "OK: \(count) runs")
                } else {
                    continuation.resume(returning: "Reply had no runs (keys: \(reply.keys.sorted().joined(separator: ", ")))")
                }
            } errorHandler: { error in
                continuation.resume(returning: "Error: \(error.localizedDescription)")
            }
        }
        lastRequestResult = "\(result) at \(Date.now.formatted(date: .omitted, time: .shortened))"
        return result.hasPrefix("OK")
    }

    @discardableResult
    nonisolated static func store(_ dictionary: [String: Any]) -> Bool {
        guard let payload = RunPayload.decode(dictionary) else { return false }
        MileageStore.savePhoneRuns(payload.runs, sentAt: payload.sentAt)
        WidgetCenter.shared.reloadAllTimelines()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didReceiveRuns, object: nil)
        }
        return true
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        guard activationState == .activated else { return }
        if !session.receivedApplicationContext.isEmpty {
            Self.store(session.receivedApplicationContext)
        }
        // Also ask the phone for the latest history now that the session is up.
        Task { @MainActor in
            _ = await WatchSessionManager.shared.requestRunsFromPhone()
        }
    }

    /// The phone becomes reachable (e.g. it comes back in range): fetch fresh history.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in
            _ = await WatchSessionManager.shared.requestRunsFromPhone()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Self.store(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Self.store(userInfo)
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
