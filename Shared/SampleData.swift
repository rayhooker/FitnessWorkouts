//
//  SampleData.swift
//  Deterministic fake runs for SwiftUI previews, widget placeholders and the Simulator.
//

import Foundation

nonisolated enum SampleData {
    static func runs(now: Date = .now, calendar: Calendar = .current) -> [RunSummary] {
        let weekStart = MileageCalculator.weekStart(for: now, calendar: calendar)
        // (weeksBack, dayOffset, miles, pace sec/mi)
        let plan: [(Int, Int, Double, Double)] = [
            (7, 1, 3.1, 560), (7, 3, 4.0, 570), (7, 6, 6.2, 590),
            (6, 0, 3.5, 555), (6, 2, 5.0, 565), (6, 5, 8.0, 600),
            (5, 1, 4.2, 550), (5, 3, 3.1, 540), (5, 6, 9.0, 605),
            (4, 1, 5.0, 560), (4, 4, 4.0, 545), (4, 6, 10.0, 610),
            (3, 0, 3.0, 530), (3, 2, 6.0, 560), (3, 5, 7.5, 585),
            (2, 1, 5.5, 555), (2, 3, 4.5, 548), (2, 6, 11.0, 600),
            (1, 1, 6.0, 552), (1, 3, 5.0, 540), (1, 4, 3.1, 520), (1, 6, 12.0, 598),
            (0, 0, 4.1, 545), (0, 2, 5.2, 558), (0, 4, 3.3, 530), (0, 5, 7.0, 590),
        ]
        return plan.compactMap { weeksBack, dayOffset, miles, pace in
            guard let week = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: weekStart),
                  let day = calendar.date(byAdding: .day, value: dayOffset, to: week),
                  let start = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: day),
                  start <= now else { return nil }
            let duration = miles * pace
            return RunSummary(id: UUID(),
                              startDate: start,
                              endDate: start.addingTimeInterval(duration),
                              duration: duration,
                              distanceMiles: miles,
                              activeEnergyKilocalories: miles * 105,
                              averageHeartRate: 148 + miles,
                              isIndoor: dayOffset == 2)
        }
        .sorted { $0.startDate > $1.startDate }
    }

    static func snapshot(now: Date = .now, goal: Double = MileageStore.defaultGoalMiles) -> MileageSnapshot {
        MileageCalculator.snapshot(from: runs(now: now), goal: goal, now: now)
    }
}
