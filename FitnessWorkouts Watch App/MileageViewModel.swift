//
//  MileageViewModel.swift
//  FitnessWorkouts Watch App
//

import Foundation
import Observation
import WidgetKit

@Observable
final class MileageViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
        case failed(String)
    }

    private(set) var snapshot: MileageSnapshot
    private(set) var state: LoadState = .idle
    private(set) var lastUpdated: Date?
    private(set) var lastPhoneSync: Date?

    var weeklyGoalMiles: Double {
        didSet {
            MileageStore.weeklyGoalMiles = weeklyGoalMiles
            rebuild()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    #if DEBUG
    /// Lets you exercise the UI in the Simulator, which has no running workouts.
    var useSampleData = false {
        didSet { Task { await refresh() } }
    }
    #endif

    /// Runs read from the watch's own HealthKit store (roughly the last 7 days).
    private var localRuns: [RunSummary]
    private let service = RunningDataService()
    private let isPreview: Bool

    init() {
        let goal = MileageStore.weeklyGoalMiles
        self.weeklyGoalMiles = goal
        self.localRuns = MileageStore.loadRuns()
        self.lastUpdated = MileageStore.lastFetchDate
        self.lastPhoneSync = MileageStore.lastPhoneSyncDate
        self.isPreview = false
        self.snapshot = MileageStore.cachedSnapshot()
    }

    /// Init for previews.
    init(previewRuns: [RunSummary], goal: Double = MileageStore.defaultGoalMiles) {
        self.weeklyGoalMiles = goal
        self.localRuns = previewRuns
        self.state = .loaded
        self.isPreview = true
        self.snapshot = MileageCalculator.snapshot(from: previewRuns, goal: goal)
    }

    /// Pulls fresh history from the iPhone (if reachable) and recent runs from the watch.
    func refresh() async {
        guard state != .loading else { return }

        #if DEBUG
        if useSampleData {
            localRuns = SampleData.runs()
            lastUpdated = .now
            rebuild()
            state = .loaded
            return
        }
        #endif

        guard service.isAvailable else {
            state = .unavailable
            return
        }

        state = .loading
        _ = await WatchSessionManager.shared.requestRunsFromPhone()

        do {
            try await service.requestAuthorization()
            let fetched = try await service.fetchRuns(from: MileageCalculator.windowStart())
            MileageStore.saveRuns(fetched)
            localRuns = fetched
            lastUpdated = .now
            rebuild()
            state = .loaded
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            rebuild()
            state = .failed(error.localizedDescription)
        }
    }

    /// Called when the iPhone pushes new history in the background.
    func phoneDataDidChange() {
        rebuild()
    }

    private func rebuild() {
        #if DEBUG
        if useSampleData {
            snapshot = MileageCalculator.snapshot(from: localRuns, goal: weeklyGoalMiles)
            return
        }
        #endif
        if isPreview {
            snapshot = MileageCalculator.snapshot(from: localRuns, goal: weeklyGoalMiles)
            return
        }
        lastPhoneSync = MileageStore.lastPhoneSyncDate
        let runs = MileageCalculator.merge(MileageStore.loadPhoneRuns(), localRuns)
        snapshot = MileageCalculator.snapshot(from: runs, goal: weeklyGoalMiles)
    }
}
