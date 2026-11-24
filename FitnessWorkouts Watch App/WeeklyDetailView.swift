//
//  WeeklyDetailView.swift
//  FitnessWorkouts Watch App
//
//  The screen the widget opens: a daily mileage chart and stats for the current week.
//

import Charts
import SwiftUI

struct WeeklyDetailView: View {
    @Environment(MileageViewModel.self) private var model

    var body: some View {
        let snapshot = model.snapshot

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Fmt.weekRange(start: snapshot.weekStart, end: snapshot.weekEnd))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Fmt.miles(snapshot.totalMiles))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tint)
                        Text("mi")
                            .font(.headline)
                    }
                    WeekOverWeekLabel(current: snapshot.totalMiles, previous: snapshot.previousWeekMiles)
                }

                DailyMilesChart(days: snapshot.days)
                    .frame(height: 90)

                Gauge(value: snapshot.goalProgress) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .gaugeStyle(.linearCapacity)
                .tint(.accentColor)

                Text(snapshot.remainingMiles > 0
                     ? "\(Fmt.miles(snapshot.remainingMiles)) mi to \(Fmt.miles(snapshot.weeklyGoalMiles, digits: 0)) mi goal"
                     : "Weekly goal reached 🎉")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                StatGrid(items: [
                    ("Runs", "\(snapshot.runCount)"),
                    ("Time", Fmt.duration(snapshot.totalDuration)),
                    ("Avg Pace", Fmt.pace(snapshot.averagePaceSecondsPerMile)),
                    ("Longest", "\(Fmt.miles(snapshot.longestRunMiles)) mi"),
                ])

                if !snapshot.runs.isEmpty {
                    Text("Runs")
                        .font(.headline)
                        .padding(.top, 4)
                    ForEach(snapshot.runs) { run in
                        NavigationLink(value: Route.run(run)) {
                            RunRow(run: run)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("This Week")
    }
}

struct DailyMilesChart: View {
    let days: [DayMileage]

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Miles", day.miles)
            )
            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.accentColor : Color.accentColor.opacity(0.55))
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .accessibilityLabel("Miles per day this week")
    }
}

struct WeekOverWeekLabel: View {
    let current: Double
    let previous: Double?

    var body: some View {
        if let previous {
            let delta = current - previous
            Label("\(delta >= 0 ? "+" : "")\(Fmt.miles(delta)) vs last week",
                  systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
                .foregroundStyle(delta >= 0 ? Color.green : Color.orange)
        }
    }
}

struct StatGrid: View {
    let items: [(String, String)]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { index in
                GridRow {
                    StatCell(title: items[index].0, value: items[index].1)
                    if index + 1 < items.count {
                        StatCell(title: items[index + 1].0, value: items[index + 1].1)
                    }
                }
            }
        }
    }
}

struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded).weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        WeeklyDetailView()
    }
    .environment(MileageViewModel(previewRuns: SampleData.runs()))
}
