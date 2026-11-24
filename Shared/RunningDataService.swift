//
//  RunningDataService.swift
//  Reads running workouts from HealthKit.
//

import Foundation
import HealthKit

nonisolated struct RunningDataService {
    private static let sharedStore = HKHealthStore()
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore? = nil) {
        self.healthStore = healthStore ?? Self.sharedStore
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let distanceType = HKQuantityType(.distanceWalkingRunning)
    private static let heartRateType = HKQuantityType(.heartRate)
    private static let energyType = HKQuantityType(.activeEnergyBurned)
    private static let bpm = HKUnit.count().unitDivided(by: .minute())

    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            Self.distanceType,
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
    }

    /// Prompts for read access the first time; a no-op once the user has answered.
    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    /// All running workouts (outdoor and treadmill) that started in `[start, end)`, newest first.
    func fetchRuns(from start: Date, to end: Date = .now) async throws -> [RunSummary] {
        let dateRange = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let running = HKQuery.predicateForWorkouts(with: .running)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [dateRange, running])

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let workouts = try await descriptor.result(for: healthStore)

        var runs: [RunSummary] = []
        runs.reserveCapacity(workouts.count)
        for workout in workouts {
            var run = Self.summary(for: workout)
            if run.distanceMiles <= 0 {
                run.distanceMiles = await distanceFromSamples(for: workout)
            }
            if run.averageHeartRate == nil {
                run.averageHeartRate = await averageHeartRateFromSamples(for: workout)
            }
            if run.activeEnergyKilocalories == nil {
                run.activeEnergyKilocalories = await energyFromSamples(for: workout)
            }
            runs.append(run)
        }
        return runs
    }

    // MARK: - Distance

    /// Distance stored on the workout itself. Tries, in order:
    /// 1. the workout's distance statistics,
    /// 2. the statistics of each workout activity (multi-activity workouts),
    /// 3. the legacy `totalDistance` property.
    static func workoutDistanceMiles(_ workout: HKWorkout) -> Double {
        if let miles = workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .mile()),
           miles > 0 {
            return miles
        }

        let activityMiles = workout.workoutActivities
            .compactMap { $0.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .mile()) }
            .reduce(0, +)
        if activityMiles > 0 { return activityMiles }

        return workout.totalDistance?.doubleValue(for: .mile()) ?? 0
    }

    /// Fallback when the workout carries no distance total: sum the Walking + Running Distance
    /// samples — first those linked to the workout, then any recorded during its time span.
    /// Statistics queries merge sources, so iPhone and Watch samples aren't double-counted.
    private func distanceFromSamples(for workout: HKWorkout) async -> Double {
        let linked = HKQuery.predicateForObjects(from: workout)
        if let miles = await sumDistance(matching: linked), miles > 0 {
            return miles
        }
        let during = HKQuery.predicateForSamples(withStart: workout.startDate,
                                                 end: workout.endDate,
                                                 options: [.strictStartDate])
        return await sumDistance(matching: during) ?? 0
    }

    private func sumDistance(matching predicate: NSPredicate) async -> Double? {
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.distanceType, predicate: predicate),
            options: .cumulativeSum
        )
        let stats = try? await query.result(for: healthStore)
        return stats?.sumQuantity()?.doubleValue(for: .mile())
    }

    // MARK: - Heart rate & energy

    /// Average of the heart-rate samples recorded during the workout (merged across sources).
    private func averageHeartRateFromSamples(for workout: HKWorkout) async -> Double? {
        let during = HKQuery.predicateForSamples(withStart: workout.startDate,
                                                 end: workout.endDate,
                                                 options: [])
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.heartRateType, predicate: during),
            options: .discreteAverage
        )
        guard let value = (try? await query.result(for: healthStore))?
            .averageQuantity()?.doubleValue(for: Self.bpm), value > 0 else { return nil }
        return value
    }

    private func energyFromSamples(for workout: HKWorkout) async -> Double? {
        for predicate in [HKQuery.predicateForObjects(from: workout),
                          HKQuery.predicateForSamples(withStart: workout.startDate,
                                                      end: workout.endDate,
                                                      options: [.strictStartDate])] {
            let query = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: Self.energyType, predicate: predicate),
                options: .cumulativeSum
            )
            if let kcal = (try? await query.result(for: healthStore))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()), kcal > 0 {
                return kcal
            }
        }
        return nil
    }

    // MARK: - Mapping

    static func summary(for workout: HKWorkout) -> RunSummary {
        let energy = workout.statistics(for: energyType)?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
            ?? workout.workoutActivities
                .compactMap { $0.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) }
                .reduce(nil) { ($0 ?? 0) + $1 }
        let heartRate = workout.statistics(for: heartRateType)?
            .averageQuantity()?.doubleValue(for: bpm)
            ?? workout.workoutActivities
                .compactMap { $0.statistics(for: heartRateType)?.averageQuantity()?.doubleValue(for: bpm) }
                .first
        let indoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false

        return RunSummary(id: workout.uuid,
                          startDate: workout.startDate,
                          endDate: workout.endDate,
                          duration: workout.duration,
                          distanceMiles: workoutDistanceMiles(workout),
                          activeEnergyKilocalories: energy,
                          averageHeartRate: heartRate,
                          isIndoor: indoor)
    }
}
