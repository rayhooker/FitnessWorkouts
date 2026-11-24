//
//  MileageStore.swift
//  Local cache. On the watch it is an App Group shared by the app and the widget;
//  on the iPhone it simply caches the last fetch.
//

import Foundation

nonisolated enum MileageStore {
    /// Must match the App Group in the targets' entitlements.
    static let appGroupID = "group.com.antelopesoft.FitnessWorkouts"
    static let defaultGoalMiles = 20.0

    private static let runsKey = "cachedRuns.v1"
    private static let fetchedAtKey = "cachedRunsFetchedAt.v1"
    private static let phoneRunsKey = "phoneRuns.v1"
    private static let phoneSentAtKey = "phoneRunsSentAt.v1"
    private static let goalKey = "weeklyGoalMiles"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var weeklyGoalMiles: Double {
        get {
            let value = defaults.double(forKey: goalKey)
            return value > 0 ? value : defaultGoalMiles
        }
        set { defaults.set(newValue, forKey: goalKey) }
    }

    // MARK: Runs read on this device

    static var lastFetchDate: Date? {
        defaults.object(forKey: fetchedAtKey) as? Date
    }

    static func saveRuns(_ runs: [RunSummary], fetchedAt: Date = .now) {
        save(runs, key: runsKey)
        defaults.set(fetchedAt, forKey: fetchedAtKey)
    }

    static func loadRuns() -> [RunSummary] { load(key: runsKey) }

    // MARK: Runs received from the iPhone (watch only)

    static var lastPhoneSyncDate: Date? {
        defaults.object(forKey: phoneSentAtKey) as? Date
    }

    static func savePhoneRuns(_ runs: [RunSummary], sentAt: Date) {
        // Ignore an older payload arriving after a newer one.
        if let last = lastPhoneSyncDate, sentAt < last { return }
        save(runs, key: phoneRunsKey)
        defaults.set(sentAt, forKey: phoneSentAtKey)
    }

    static func loadPhoneRuns() -> [RunSummary] { load(key: phoneRunsKey) }

    // MARK: Combined

    /// Phone history merged with this device's own runs.
    static func allRuns() -> [RunSummary] {
        MileageCalculator.merge(loadPhoneRuns(), loadRuns())
    }

    /// Snapshot rebuilt from the cache against the *current* date, so a stale cache
    /// still rolls over correctly when a new week starts.
    static func cachedSnapshot(now: Date = .now) -> MileageSnapshot {
        MileageCalculator.snapshot(from: allRuns(), goal: weeklyGoalMiles, now: now)
    }

    // MARK: Helpers

    private static func save(_ runs: [RunSummary], key: String) {
        guard let data = try? JSONEncoder().encode(runs) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(key: String) -> [RunSummary] {
        guard let data = defaults.data(forKey: key),
              let runs = try? JSONDecoder().decode([RunSummary].self, from: data) else { return [] }
        return runs
    }
}
