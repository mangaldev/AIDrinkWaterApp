import Foundation
import UserNotifications

/// Plans the free build's notifications.
///
/// iOS doesn't let an app open itself, so a notification is the strongest nudge we have.
/// At each reminder time you get a notification, then follow-ups every few minutes until you
/// drink or skip. Tapping any of them opens DrinkWater straight into the camera check.
///
/// Notifications are planned for the next 2 days and re-planned whenever the app opens,
/// you drink, or you skip (iOS allows at most 64 pending notifications).
enum NotificationPlanner {
    static let followUpMinutes = [5, 10, 15, 20]
    private static let maxPending = 60

    static func replan(schedule: ReminderSchedule, lastCleared: Date?, now: Date = Date(),
                       calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard schedule.enabled else { return }

        var requests: [UNNotificationRequest] = []

        // 1. Follow-ups for a reminder that's due right now and not yet handled.
        if schedule.isDue(lastCleared: lastCleared, now: now),
           let due = schedule.mostRecentReminder(before: now, calendar: calendar) {
            for m in followUpMinutes {
                let fire = due.addingTimeInterval(TimeInterval(m * 60))
                if fire > now { requests.append(request(at: fire, followUp: true, calendar: calendar)) }
            }
        }

        // 2. Upcoming reminders (with their follow-ups) for the next 2 days.
        let startOfToday = calendar.startOfDay(for: now)
        outer: for dayOffset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            for minute in schedule.minutesOfDay {
                let fire = day.addingTimeInterval(TimeInterval(minute * 60))
                guard fire > now else { continue }
                if requests.count >= maxPending { break outer }
                requests.append(request(at: fire, followUp: false, calendar: calendar))
                for m in followUpMinutes where requests.count < maxPending {
                    requests.append(request(at: fire.addingTimeInterval(TimeInterval(m * 60)),
                                            followUp: true, calendar: calendar))
                }
            }
        }

        // Follow-ups for later reminders are dropped first if we're over the cap.
        for r in requests.prefix(maxPending) { center.add(r) }
    }

    /// Clears follow-ups already sitting in Notification Center once you've drunk or skipped.
    static func clearDelivered() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private static func request(at date: Date, followUp: Bool, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = followUp ? "Still waiting on that glass 💧" : "Time to drink water 💧"
        content.body = "Tap to open SipProof and take a sip on camera."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNNotificationRequest(identifier: "drink-\(Int(date.timeIntervalSince1970))",
                                     content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
    }
}
