import Foundation

/// One entry in the history: a verified glass, or a reminder that was skipped.
struct DrinkEvent: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case drank     // camera saw you drink
        case missed    // you tapped "Skip for now" on a reminder
    }
    enum Source: String, Codable {
        case reminder  // during a reminder lock
        case manual    // from "Add a glass"
    }

    var id = UUID()
    var date: Date
    var kind: Kind
    var source: Source
}

/// Per-day totals for the chart and history list.
struct DaySummary: Identifiable {
    var day: Date          // start of day
    var drank: Int
    var missed: Int
    var id: Date { day }
}

/// Stores the history as JSON in UserDefaults. Fine for years of a few entries a day.
@MainActor
final class DrinkLog: ObservableObject {
    @Published private(set) var events: [DrinkEvent] = []

    private let key = "drinkEvents"
    private var defaults: UserDefaults { SharedStore.defaults }

    init() {
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([DrinkEvent].self, from: data) {
            events = saved.sorted { $0.date > $1.date }
        }
    }

    func add(_ kind: DrinkEvent.Kind, source: DrinkEvent.Source, at date: Date = Date()) {
        events.insert(DrinkEvent(date: date, kind: kind, source: source), at: 0)
        save()
    }

    func delete(_ event: DrinkEvent) {
        events.removeAll { $0.id == event.id }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(events), forKey: key)
    }

    // MARK: Queries

    func entries(on day: Date, calendar: Calendar = .current) -> [DrinkEvent] {
        events.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func drankCount(on day: Date) -> Int {
        entries(on: day).filter { $0.kind == .drank }.count
    }

    func missedCount(on day: Date) -> Int {
        entries(on: day).filter { $0.kind == .missed }.count
    }

    /// The last `days` days, oldest first, including days with nothing logged.
    func summaries(days: Int, calendar: Calendar = .current) -> [DaySummary] {
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DaySummary(day: day, drank: drankCount(on: day), missed: missedCount(on: day))
        }
    }

    /// Every day that has at least one entry, newest first.
    func loggedDays(calendar: Calendar = .current) -> [Date] {
        Array(Set(events.map { calendar.startOfDay(for: $0.date) })).sorted(by: >)
    }
}
