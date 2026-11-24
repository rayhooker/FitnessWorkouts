//
//  RunDetailView.swift
//  FitnessWorkouts Watch App
//

import SwiftUI

struct RunDetailView: View {
    let run: RunSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(run.startDate.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Fmt.miles(run.distanceMiles, digits: 2))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tint)
                        Text("mi").font(.headline)
                    }
                    Label(run.isIndoor ? "Indoor Run" : "Outdoor Run",
                          systemImage: run.isIndoor ? "figure.run.treadmill" : "figure.run")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                StatGrid(items: [
                    ("Time", Fmt.duration(run.duration)),
                    ("Pace", "\(Fmt.pace(run.paceSecondsPerMile)) /mi"),
                    ("Calories", run.activeEnergyKilocalories.map { "\(Int($0.rounded()))" } ?? "--"),
                    ("Avg HR", run.averageHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--"),
                    ("Start", run.startDate.formatted(date: .omitted, time: .shortened)),
                    ("End", run.endDate.formatted(date: .omitted, time: .shortened)),
                ])
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Run")
    }
}

#Preview {
    NavigationStack {
        RunDetailView(run: SampleData.runs().first!)
    }
}
