//
//  ContentView.swift
//  FitnessWorkouts Watch App
//
//  Created by Ray Hooker on 11/21/26.
//

import Combine
import SwiftUI

struct ContentView: View {
    @Environment(MileageViewModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Binding var path: [Route]

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: Route.weekDetail) {
                        WeeklySummaryCard(snapshot: model.snapshot)
                    }
                    .accessibilityHint("Shows this week's chart and runs")
                }

                Section {
                    NavigationLink(value: Route.trend) {
                        Label("Last \(model.snapshot.weeks.count) Weeks", systemImage: "chart.bar.xaxis")
                    }
                    NavigationLink(value: Route.goal) {
                        Label("Goal: \(Fmt.miles(model.weeklyGoalMiles, digits: 0)) mi", systemImage: "target")
                    }
                    NavigationLink(value: Route.syncStatus) {
                        Label("Sync Status", systemImage: "iphone.radiowaves.left.and.right")
                    }
                }

                Section("This Week") {
                    if model.snapshot.runs.isEmpty {
                        Text("No runs yet this week")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.snapshot.runs) { run in
                            NavigationLink(value: Route.run(run)) {
                                RunRow(run: run)
                            }
                        }
                    }
                }

                Section {
                    StatusFooter(state: model.state,
                                 lastUpdated: model.lastUpdated,
                                 lastPhoneSync: model.lastPhoneSync)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Weekly Miles")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .weekDetail: WeeklyDetailView()
                case .trend: TrendView()
                case .run(let run): RunDetailView(run: run)
                case .goal: GoalSettingsView()
                case .syncStatus: SyncStatusView()
                }
            }
        }
        .task { await model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: WatchSessionManager.didReceiveRuns)) { _ in
            model.phoneDataDidChange()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
    }
}

// MARK: - Summary card

struct WeeklySummaryCard: View {
    let snapshot: MileageSnapshot

    var body: some View {
        HStack(spacing: 10) {
            ProgressRing(progress: snapshot.goalProgress)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 1) {
                Text(Fmt.miles(snapshot.totalMiles))
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(.tint)
                    .contentTransition(.numericText())
                Text("mi this week")
                    .font(.footnote)
                Text("\(snapshot.runCount) run\(snapshot.runCount == 1 ? "" : "s") · goal \(Fmt.miles(snapshot.weeklyGoalMiles, digits: 0))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: progress >= 1 ? "checkmark" : "figure.run")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)
        }
        .animation(.easeOut, value: progress)
        .accessibilityLabel("\(Int(progress * 100)) percent of weekly goal")
    }
}

struct RunRow: View {
    let run: RunSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(Fmt.miles(run.distanceMiles, digits: 2)) mi")
                    .font(.headline)
                if run.isIndoor {
                    Image(systemName: "figure.run.treadmill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Indoor")
                }
            }
            Text("\(run.startDate.formatted(.dateTime.month(.abbreviated).day())) · \(Fmt.duration(run.duration)) · \(Fmt.pace(run.paceSecondsPerMile))/mi")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        // The lines are left-aligned with each other (ragged right edge), and the block as a
        // whole is centered in the button, like standard multiline button text.
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
    }
}

private struct StatusFooter: View {
    let state: MileageViewModel.LoadState
    let lastUpdated: Date?
    let lastPhoneSync: Date?

    var body: some View {
        VStack(spacing: 2) {
            status
            if let lastPhoneSync {
                Text("iPhone history \(lastPhoneSync.formatted(.relative(presentation: .named)))")
            } else {
                Text("Open FitnessWorkouts on iPhone to load past weeks")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var status: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .unavailable:
                Text("Health data isn't available on this device.")
            case .failed(let message):
                Text("Couldn't load runs: \(message)")
            case .idle, .loaded:
                if let lastUpdated {
                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                }
            }
        }
    }
}

#Preview {
    ContentView(path: .constant([]))
        .environment(MileageViewModel(previewRuns: SampleData.runs()))
}
