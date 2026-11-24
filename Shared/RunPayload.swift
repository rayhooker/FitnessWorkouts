//
//  RunPayload.swift
//  The dictionary format the iPhone app uses to send run history to the watch
//  over WatchConnectivity.
//

import Foundation

nonisolated enum RunPayload {
    static let runsKey = "runs"
    static let sentAtKey = "sentAt"
    /// Message key the watch sends to ask the iPhone for fresh history.
    static let requestKey = "requestRuns"

    static func encode(_ runs: [RunSummary], sentAt: Date = .now) -> [String: Any] {
        let data = (try? JSONEncoder().encode(runs)) ?? Data()
        return [runsKey: data, sentAtKey: sentAt]
    }

    static func decode(_ dictionary: [String: Any]) -> (runs: [RunSummary], sentAt: Date)? {
        guard let data = dictionary[runsKey] as? Data,
              let runs = try? JSONDecoder().decode([RunSummary].self, from: data) else { return nil }
        return (runs, dictionary[sentAtKey] as? Date ?? .now)
    }
}

/// One row of the Sync Status screens (shown on both iPhone and watch).
nonisolated struct SyncStatusLine: Identifiable, Hashable, Sendable {
    let label: String
    let value: String
    var id: String { label }
}
