import Foundation

/// "Every N minutes between startHour and endHour", repeating daily.
struct ReminderSchedule: Codable, Equatable {
    var startHour = 8
    var endHour = 22
    var everyMinutes = 120
    var enabled = true

    /// iOS lets one app monitor about 20 activities, so we cap the number of daily reminders.
    static let maxReminders = 20

    /// Reminder times as minutes since midnight.
    var minutesOfDay: [Int] {
        guard everyMinutes >= 15, endHour > startHour else { return [] }
        let times = stride(from: startHour * 60, through: endHour * 60, by: everyMinutes)
        return Array(times.prefix(Self.maxReminders))
    }

    /// The latest reminder time at or before `now` (today, or the last one yesterday).
    func mostRecentReminder(before now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let times = minutesOfDay
        guard enabled, let last = times.last else { return nil }
        let startOfDay = calendar.startOfDay(for: now)
        let nowMinute = Int(now.timeIntervalSince(startOfDay) / 60)
        if let today = times.last(where: { $0 <= nowMinute }) {
            return startOfDay.addingTimeInterval(TimeInterval(today * 60))
        }
        return calendar.date(byAdding: .day, value: -1, to: startOfDay)?
            .addingTimeInterval(TimeInterval(last * 60))
    }

    /// True when a reminder has passed that the user hasn't drunk (or skipped) for yet.
    func isDue(lastCleared: Date?, now: Date = Date()) -> Bool {
        guard let reminder = mostRecentReminder(before: now) else { return false }
        guard let lastCleared else { return true }
        return lastCleared < reminder
    }
}
