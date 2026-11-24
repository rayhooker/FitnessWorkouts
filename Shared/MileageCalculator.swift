//
//  MileageCalculator.swift
//  Pure aggregation logic: runs in → weekly snapshot out. No HealthKit here, so it is easy to test.
//

import Foundation

nonisolated enum MileageCalculator {
    /// Number of weeks of history shown in the trend chart (including the current week).
    static let defaultWeekCount = 8

    /// Start of the calendar week containing `date`, honoring the user's first weekday.
    static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// The earliest date we need from HealthKit to fill `weekCount` weeks.
    static func windowStart(now: Date = .now,
                            calendar: Calendar = .current,
                            weekCount: Int = defaultWeekCount) -> Date {
        let current = weekStart(for: now, calendar: calendar)
        return calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: current) ?? current
    }

    /// Combines run lists from different sources (the iPhone's full history and the watch's
    /// own recent data). The same workout synced to both devices keeps its HealthKit UUID, so
    /// duplicates are collapsed by ID — keeping whichever copy has the larger distance, since a
    /// device may not have that run's distance samples. As a safety net, entries with the same
    /// start time and duration are also treated as the same workout.
    /// Distinct workouts (indoor, outdoor, other apps or devices) are all kept, matching how
    /// Apple Fitness totals runs.
    static func merge(_ lists: [RunSummary]...) -> [RunSummary] {
        var byKey: [String: RunSummary] = [:]
        var idToKey: [UUID: String] = [:]
        for run in lists.joined() {
            let fingerprint = "\(Int(run.startDate.timeIntervalSinceReferenceDate))-\(Int(run.duration.rounded()))"
            let key = idToKey[run.id] ?? fingerprint
            if let existing = byKey[key], existing.distanceMiles >= run.distanceMiles {
                idToKey[run.id] = key
                continue
            }
            byKey[key] = run
            idToKey[run.id] = key
        }
        return byKey.values.sorted { $0.startDate > $1.startDate }
    }

    static func snapshot(from runs: [RunSummary],
                         goal: Double,
                         now: Date = .now,
                         calendar: Calendar = .current,
                         weekCount: Int = defaultWeekCount) -> MileageSnapshot {
        let start = weekStart(for: now, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86_400)

        let days: [DayMileage] = (0..<7).compactMap { offset in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let miles = runs
                .filter { calendar.isDate($0.startDate, inSameDayAs: dayStart) }
                .reduce(0) { $0 + $1.distanceMiles }
            return DayMileage(date: dayStart, miles: miles)
        }

        let weeks: [WeekMileage] = (0..<max(weekCount, 1)).reversed().compactMap { weeksBack in
            guard let wStart = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: start),
                  let wEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: wStart) else { return nil }
            let weekRuns = runs.filter { $0.startDate >= wStart && $0.startDate < wEnd }
            return WeekMileage(weekStart: wStart,
                               miles: weekRuns.reduce(0) { $0 + $1.distanceMiles },
                               runCount: weekRuns.count)
        }

        let currentRuns = runs
            .filter { $0.startDate >= start && $0.startDate < end }
            .sorted { $0.startDate > $1.startDate }

        return MileageSnapshot(generatedAt: now,
                               weekStart: start,
                               weekEnd: end,
                               days: days,
                               weeks: weeks,
                               runs: currentRuns,
                               weeklyGoalMiles: goal)
    }
}
