//
//  WeeklyMilesWidget.swift
//  WeeklyMilesWidget
//
//  Watch face complication / Smart Stack widget showing this week's running miles.
//  Tapping it opens the app on the weekly chart.
//

import Charts
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct MileageEntry: TimelineEntry {
    let date: Date
    let snapshot: MileageSnapshot
}

struct MileageProvider: TimelineProvider {
    func placeholder(in context: Context) -> MileageEntry {
        MileageEntry(date: .now, snapshot: SampleData.snapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (MileageEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(MileageEntry(date: .now, snapshot: MileageStore.cachedSnapshot()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MileageEntry>) -> Void) {
        Task {
            let entry = await Self.freshEntry()
            // Refresh every 30 minutes, and exactly when the week rolls over so the count resets.
            let halfHour = Date.now.addingTimeInterval(30 * 60)
            let next = min(halfHour, entry.snapshot.weekEnd)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    /// Tries HealthKit first (the app has already obtained authorization), falling back to the
    /// App Group cache that the app writes on every refresh.
    private static func freshEntry() async -> MileageEntry {
        let now = Date.now
        let service = RunningDataService()
        if service.isAvailable,
           let runs = try? await service.fetchRuns(from: MileageCalculator.windowStart(now: now), to: now),
           !runs.isEmpty {
            // An empty result can simply mean "not authorized" or "device locked", so only
            // overwrite the cache with real data.
            MileageStore.saveRuns(runs, fetchedAt: now)
        }
        return MileageEntry(date: now, snapshot: MileageStore.cachedSnapshot(now: now))
    }
}

// MARK: - Views

struct WeeklyMilesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MileageEntry

    private var snapshot: MileageSnapshot { entry.snapshot }
    private var milesText: String {
        Fmt.miles(snapshot.totalMiles, digits: snapshot.totalMiles >= 100 ? 0 : 1)
    }

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(DeepLink.weeklyDetail)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            corner
        case .accessoryInline:
            Label("\(milesText) mi this week", systemImage: "figure.run")
        default:
            rectangular
        }
    }

    private var circular: some View {
        Gauge(value: snapshot.goalProgress) {
            Image(systemName: "figure.run")
        } currentValueLabel: {
            Text(milesText)
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .accessibilityLabel("\(milesText) miles this week, \(Int(snapshot.goalProgress * 100)) percent of goal")
    }

    private var corner: some View {
        Text(milesText)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .widgetCurvesContent()
            .widgetLabel {
                Gauge(value: snapshot.goalProgress) {
                    Text("MI")
                } currentValueLabel: {
                    Text(milesText)
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text(Fmt.miles(snapshot.weeklyGoalMiles, digits: 0))
                }
                .tint(.accentColor)
            }
    }

    private var rectangular: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Label("This Week", systemImage: "figure.run")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .widgetAccentable()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(milesText)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                    Text("mi")
                        .font(.caption2)
                }
                Text("\(snapshot.runCount) run\(snapshot.runCount == 1 ? "" : "s") · \(Int(snapshot.goalProgress * 100))% of \(Fmt.miles(snapshot.weeklyGoalMiles, digits: 0))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Chart(snapshot.days) { day in
                BarMark(x: .value("Day", day.date, unit: .day),
                        y: .value("Miles", day.miles))
                    .cornerRadius(1.5)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .widgetAccentable()
            .frame(width: 44)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Widget

struct WeeklyMilesWidget: Widget {
    let kind = "WeeklyMilesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MileageProvider()) { entry in
            WeeklyMilesWidgetView(entry: entry)
        }
        .configurationDisplayName("Weekly Miles")
        .description("Running miles for the current week.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

@main
struct WeeklyMilesWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeeklyMilesWidget()
    }
}

// MARK: - Previews

#Preview("Rectangular", as: .accessoryRectangular) {
    WeeklyMilesWidget()
} timeline: {
    MileageEntry(date: .now, snapshot: SampleData.snapshot())
}

#Preview("Circular", as: .accessoryCircular) {
    WeeklyMilesWidget()
} timeline: {
    MileageEntry(date: .now, snapshot: SampleData.snapshot())
}

#Preview("Corner", as: .accessoryCorner) {
    WeeklyMilesWidget()
} timeline: {
    MileageEntry(date: .now, snapshot: SampleData.snapshot())
}
