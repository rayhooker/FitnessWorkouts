//
//  FitnessWorkouts_Watch_AppTests.swift
//  FitnessWorkouts Watch AppTests
//
//  Created by Ray Hooker on 11/21/26.
//

import Foundation
import Testing
@testable import FitnessWorkouts_Watch_App

struct MileageCalculatorTests {
    /// Fixed Sunday-first Gregorian calendar so results don't depend on the test machine's locale.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        cal.firstWeekday = 1
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 7) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func run(_ start: Date, miles: Double, minutes: Double = 30) -> RunSummary {
        RunSummary(id: UUID(), startDate: start, endDate: start.addingTimeInterval(minutes * 60),
                   duration: minutes * 60, distanceMiles: miles)
    }

    // Saturday Nov 21 2026; week runs Sun Nov 15 – Sat Nov 21.
    private var now: Date { date(2026, 11, 21, 12) }

    @Test func totalsOnlyCurrentWeek() {
        let runs = [
            run(date(2026, 11, 14), miles: 10),   // last Saturday – previous week
            run(date(2026, 11, 15), miles: 3),    // Sunday – this week
            run(date(2026, 11, 18), miles: 4.5),
            run(date(2026, 11, 21), miles: 2.5),
        ]
        let snap = MileageCalculator.snapshot(from: runs, goal: 20, now: now, calendar: calendar)

        #expect(snap.totalMiles == 10)
        #expect(snap.runCount == 3)
        #expect(snap.previousWeekMiles == 10)
        #expect(snap.goalProgress == 0.5)
        #expect(snap.remainingMiles == 10)
    }

    @Test func buildsSevenDaysAndEightWeeks() {
        let snap = MileageCalculator.snapshot(from: [], goal: 20, now: now, calendar: calendar)
        #expect(snap.days.count == 7)
        #expect(snap.weeks.count == 8)
        #expect(snap.weeks.last?.weekStart == snap.weekStart)
        #expect(calendar.component(.weekday, from: snap.weekStart) == 1)
    }

    @Test func dailyBucketsByStartDay() {
        let runs = [
            run(date(2026, 11, 18, 6), miles: 2),
            run(date(2026, 11, 18, 18), miles: 3),
        ]
        let snap = MileageCalculator.snapshot(from: runs, goal: 20, now: now, calendar: calendar)
        // Wednesday is index 3 for a Sunday-first week.
        #expect(snap.days[3].miles == 5)
        #expect(snap.days.filter { $0.miles > 0 }.count == 1)
    }

    @Test func progressCapsAtOne() {
        let snap = MileageCalculator.snapshot(from: [run(date(2026, 11, 16), miles: 30)],
                                              goal: 20, now: now, calendar: calendar)
        #expect(snap.goalProgress == 1)
        #expect(snap.remainingMiles == 0)
    }

    @Test func paceAndFormatting() {
        let r = run(date(2026, 11, 16), miles: 3, minutes: 27)   // 9:00 /mi
        #expect(Fmt.pace(r.paceSecondsPerMile) == "9:00")
        #expect(Fmt.duration(3_932) == "1:05:32")
        #expect(Fmt.duration(1_620) == "27:00")
    }

    @Test func mergeKeepsDistinctRunsFromEverySource() {
        // Phone history: 5 runs in the week of Nov 8, three of them indoor / from other apps.
        let phone = [
            run(date(2026, 11, 8), miles: 3.1),
            run(date(2026, 11, 9), miles: 4.0),
            run(date(2026, 11, 10), miles: 5.0),
            run(date(2026, 11, 12), miles: 3.0),
            run(date(2026, 11, 14), miles: 8.0),
        ]
        // Watch only has the latest run, and without its distance.
        var watchCopy = phone[4]
        watchCopy.distanceMiles = 0
        let merged = MileageCalculator.merge(phone, [watchCopy])

        #expect(merged.count == 5)
        #expect(merged.first?.distanceMiles == 8.0)
        let snap = MileageCalculator.snapshot(from: merged, goal: 20, now: now, calendar: calendar)
        #expect(abs((snap.previousWeekMiles ?? 0) - 23.1) < 0.001)
        #expect(snap.weeks[snap.weeks.count - 2].runCount == 5)
    }

    @Test func mergeCollapsesSameWorkoutWithDifferentIDs() {
        let a = run(date(2026, 11, 16), miles: 0)
        var b = a
        b.id = UUID()
        b.distanceMiles = 4.2
        let merged = MileageCalculator.merge([a], [b])
        #expect(merged.count == 1)
        #expect(merged.first?.distanceMiles == 4.2)
    }

    @Test func payloadRoundTrips() {
        let runs = [run(date(2026, 11, 16), miles: 4.2)]
        let decoded = RunPayload.decode(RunPayload.encode(runs))
        #expect(decoded?.runs == runs)
    }

    @Test func windowStartCoversEightWeeks() {
        let start = MileageCalculator.windowStart(now: now, calendar: calendar, weekCount: 8)
        #expect(start == date(2026, 9, 27, 0))
    }
}
