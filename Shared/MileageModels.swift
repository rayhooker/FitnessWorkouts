//
//  MileageModels.swift
//  Shared between the Watch App and the Weekly Miles widget.
//

import Foundation

/// A single running workout, reduced to the values the app and widget display.
nonisolated struct RunSummary: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var duration: TimeInterval
    var distanceMiles: Double
    var activeEnergyKilocalories: Double?
    var averageHeartRate: Double?
    var isIndoor: Bool = false

    /// Seconds per mile, or nil when the distance is too small to be meaningful.
    var paceSecondsPerMile: TimeInterval? {
        guard distanceMiles > 0.01, duration > 0 else { return nil }
        return duration / distanceMiles
    }
}

/// Miles run on one calendar day.
nonisolated struct DayMileage: Codable, Hashable, Identifiable, Sendable {
    var date: Date
    var miles: Double
    var id: Date { date }
}

/// Miles run during one calendar week.
nonisolated struct WeekMileage: Codable, Hashable, Identifiable, Sendable {
    var weekStart: Date
    var miles: Double
    var runCount: Int
    var id: Date { weekStart }
}

/// Everything the UI needs for the current week plus recent history.
nonisolated struct MileageSnapshot: Codable, Hashable, Sendable {
    var generatedAt: Date
    var weekStart: Date
    var weekEnd: Date
    /// Seven entries, one per day of the current week.
    var days: [DayMileage]
    /// Oldest → newest. The last element is the current week.
    var weeks: [WeekMileage]
    /// The current week's runs, newest first.
    var runs: [RunSummary]
    var weeklyGoalMiles: Double

    var totalMiles: Double { runs.reduce(0) { $0 + $1.distanceMiles } }
    var runCount: Int { runs.count }
    var totalDuration: TimeInterval { runs.reduce(0) { $0 + $1.duration } }
    var longestRunMiles: Double { runs.map(\.distanceMiles).max() ?? 0 }

    var averagePaceSecondsPerMile: TimeInterval? {
        guard totalMiles > 0.01 else { return nil }
        return totalDuration / totalMiles
    }

    /// 0...1 progress toward the weekly goal.
    var goalProgress: Double {
        guard weeklyGoalMiles > 0 else { return 0 }
        return min(totalMiles / weeklyGoalMiles, 1)
    }

    var remainingMiles: Double { max(weeklyGoalMiles - totalMiles, 0) }

    var previousWeekMiles: Double? {
        weeks.count >= 2 ? weeks[weeks.count - 2].miles : nil
    }

    /// Average of the completed weeks in `weeks` (excludes the current week).
    var averageWeeklyMiles: Double {
        let completed = weeks.dropLast()
        guard !completed.isEmpty else { return 0 }
        return completed.reduce(0) { $0 + $1.miles } / Double(completed.count)
    }

    var bestWeek: WeekMileage? { weeks.max { $0.miles < $1.miles } }
}

/// Routes the app can navigate to. Shared so the widget can deep-link.
nonisolated enum DeepLink {
    static let scheme = "fitnessworkouts"
    static let weeklyDetail = URL(string: "fitnessworkouts://week")!
    static let trend = URL(string: "fitnessworkouts://trend")!
}
