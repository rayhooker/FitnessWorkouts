//
//  TrendView.swift
//  FitnessWorkouts Watch App
//
//  Weekly mileage for the last several weeks, with the goal drawn as a rule.
//

import Charts
import SwiftUI

struct TrendView: View {
    @Environment(MileageViewModel.self) private var model

    var body: some View {
        let snapshot = model.snapshot

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Chart {
                    ForEach(snapshot.weeks) { week in
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Miles", week.miles)
                        )
                        .foregroundStyle(week.weekStart == snapshot.weekStart
                                         ? Color.accentColor
                                         : Color.accentColor.opacity(0.55))
                        .cornerRadius(3)
                    }
                    RuleMark(y: .value("Goal", snapshot.weeklyGoalMiles))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(.secondary)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 110)
                .accessibilityLabel("Miles per week")

                StatGrid(items: [
                    ("This Week", "\(Fmt.miles(snapshot.totalMiles)) mi"),
                    ("Avg / Week", "\(Fmt.miles(snapshot.averageWeeklyMiles)) mi"),
                    ("Best Week", "\(Fmt.miles(snapshot.bestWeek?.miles ?? 0)) mi"),
                    ("Total Runs", "\(snapshot.weeks.reduce(0) { $0 + $1.runCount })"),
                ])

                VStack(spacing: 4) {
                    ForEach(snapshot.weeks.reversed()) { week in
                        HStack {
                            Text(week.weekStart.formatted(.dateTime.month(.abbreviated).day()))
                            Spacer()
                            Text("\(Fmt.miles(week.miles)) mi")
                                .foregroundStyle(week.miles >= snapshot.weeklyGoalMiles ? Color.green : Color.primary)
                        }
                        .font(.footnote)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Trend")
    }
}

#Preview {
    NavigationStack {
        TrendView()
    }
    .environment(MileageViewModel(previewRuns: SampleData.runs()))
}
