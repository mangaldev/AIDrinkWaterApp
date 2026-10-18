import SwiftUI
import Charts

/// Chart of glasses per day, plus every entry with its timestamp, grouped by day.
struct StatsView: View {
    @EnvironmentObject var log: DrinkLog
    @State private var range = 7

    private var summaries: [DaySummary] { log.summaries(days: range) }
    private var average: Double {
        guard !summaries.isEmpty else { return 0 }
        return Double(summaries.map(\.drank).reduce(0, +)) / Double(summaries.count)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $range) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                    }
                    .pickerStyle(.segmented)

                    Chart {
                        ForEach(summaries) { d in
                            BarMark(x: .value("Day", d.day, unit: .day),
                                    y: .value("Glasses", d.drank))
                                .foregroundStyle(by: .value("Type", "Drank"))
                            if d.missed > 0 {
                                BarMark(x: .value("Day", d.day, unit: .day),
                                        y: .value("Glasses", d.missed))
                                    .foregroundStyle(by: .value("Type", "Missed"))
                            }
                        }
                        RuleMark(y: .value("Average", average))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(.secondary)
                    }
                    .chartForegroundStyleScale(["Drank": Color.blue, "Missed": Color.red.opacity(0.6)])
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 5)) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .frame(height: 220)

                    HStack {
                        StatTile(title: "Average", value: String(format: "%.1f", average), unit: "per day")
                        StatTile(title: "Total", value: "\(summaries.map(\.drank).reduce(0, +))", unit: "glasses")
                        StatTile(title: "Missed", value: "\(summaries.map(\.missed).reduce(0, +))", unit: "skips")
                    }
                }

                ForEach(log.loggedDays(), id: \.self) { day in
                    Section {
                        ForEach(log.entries(on: day)) { EventRow(event: $0) }
                    } header: {
                        HStack {
                            Text(day, format: .dateTime.weekday(.wide).day().month())
                            Spacer()
                            Text("\(log.drankCount(on: day)) glasses")
                        }
                    }
                }
                if log.events.isEmpty {
                    Text("Your glasses will show up here.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Stats")
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
