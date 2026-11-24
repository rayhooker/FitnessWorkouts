//
//  PhoneContentView.swift
//  FitnessWorkouts (iPhone)
//

import SwiftUI

struct PhoneContentView: View {
    @Environment(PhoneModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let snapshot = model.snapshot

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Fmt.weekRange(start: snapshot.weekStart, end: snapshot.weekEnd))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(Fmt.miles(snapshot.totalMiles))
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundStyle(.tint)
                            Text("mi this week")
                                .font(.title3)
                        }
                        Text("\(snapshot.runCount) run\(snapshot.runCount == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("This Week's Runs") {
                    if snapshot.runs.isEmpty {
                        Text("No runs yet this week").foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.runs) { run in
                            PhoneRunRow(run: run)
                        }
                    }
                }

                Section("Last \(snapshot.weeks.count) Weeks") {
                    ForEach(snapshot.weeks.reversed()) { week in
                        HStack {
                            Text("Week of \(week.weekStart.formatted(.dateTime.month(.abbreviated).day()))")
                            Spacer()
                            Text("\(week.runCount) run\(week.runCount == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                            Text("\(Fmt.miles(week.miles)) mi")
                                .monospacedDigit()
                                .frame(minWidth: 64, alignment: .trailing)
                        }
                    }
                }

                Section("Sync Status") {
                    ForEach(model.syncStatus) { line in
                        LabeledContent(line.label, value: line.value)
                    }
                }

                Section {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        HStack {
                            Label("Sync to Apple Watch", systemImage: "applewatch.radiowaves.left.and.right")
                            Spacer()
                            if model.isLoading { ProgressView() }
                        }
                    }
                    .disabled(model.isLoading)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let error = model.errorMessage {
                            Text("Couldn't read Health data: \(error)")
                                .foregroundStyle(.red)
                        }
                        if !model.watchAppInstalled {
                            Text("Install FitnessWorkouts on your Apple Watch to see these totals on your wrist.")
                        }
                        if let lastSynced = model.lastSynced {
                            Text("Read from Health \(lastSynced.formatted(.relative(presentation: .named))).")
                        }
                        Text("Includes every running workout in Health — indoor, outdoor and from other apps or devices. If miles look wrong, check Health → Profile → Apps → FitnessWorkouts and turn on Workouts and Walking + Running Distance.")
                    }
                }
            }
            .navigationTitle("Weekly Miles")
            .refreshable { await model.refresh() }
        }
        .task {
            model.reloadSyncStatus()
            await model.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
    }
}

struct PhoneRunRow: View {
    let run: RunSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(run.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                Text("\(Fmt.duration(run.duration)) · \(Fmt.pace(run.paceSecondsPerMile)) /mi\(run.isIndoor ? " · Indoor" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Fmt.miles(run.distanceMiles, digits: 2)) mi")
                .font(.headline)
                .monospacedDigit()
        }
    }
}

#Preview {
    PhoneContentView()
        .environment(PhoneModel())
}
