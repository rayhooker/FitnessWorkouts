//
//  PhoneModel.swift
//  FitnessWorkouts (iPhone)
//

import Foundation
import Observation

@Observable
final class PhoneModel {
    private(set) var snapshot: MileageSnapshot
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastSynced: Date?
    private(set) var syncStatus: [SyncStatusLine] = []

    init() {
        snapshot = MileageCalculator.snapshot(from: MileageStore.loadRuns(),
                                              goal: MileageStore.weeklyGoalMiles)
        lastSynced = MileageStore.lastFetchDate
    }

    var watchAppInstalled: Bool { PhoneSessionManager.shared.isWatchAppInstalled }

    func reloadSyncStatus() {
        syncStatus = PhoneSessionManager.shared.statusLines
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            reloadSyncStatus()
        }

        do {
            try await RunningDataService().requestAuthorization()
            HealthBackgroundSync.start()
            let runs = try await PhoneSync.fetchAndPush()
            snapshot = MileageCalculator.snapshot(from: runs, goal: MileageStore.weeklyGoalMiles)
            lastSynced = .now
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
