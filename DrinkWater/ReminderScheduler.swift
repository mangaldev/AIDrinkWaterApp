import Foundation
import UserNotifications
#if SCREEN_TIME
import DeviceActivity
#endif

enum ReminderScheduler {
    static func apply(_ schedule: ReminderSchedule) throws {
        #if SCREEN_TIME
        try applyScreenTime(schedule)
        #else
        applyNotifications(schedule)
        #endif
    }

    /// Free build: one daily-repeating notification per reminder time.
    /// Tapping it opens the app, which shows the drink check.
    static func applyNotifications(_ schedule: ReminderSchedule) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard schedule.enabled else { return }

        for minute in schedule.minutesOfDay {
            let content = UNMutableNotificationContent()
            content.title = "Time to drink water 💧"
            content.body = "Open DrinkWater and take a sip on camera."
            content.sound = .default
            let when = DateComponents(hour: minute / 60, minute: minute % 60)
            let req = UNNotificationRequest(identifier: "drink-\(minute)",
                                            content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
            center.add(req)
        }
    }

    #if SCREEN_TIME
    /// Paid build: registers one daily-repeating DeviceActivity per reminder time. At each start
    /// time iOS wakes DrinkMonitor (the extension), which shields all apps and posts a notification.
    static func applyScreenTime(_ schedule: ReminderSchedule) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring()
        guard schedule.enabled else { return }

        for minute in schedule.minutesOfDay {
            // iOS requires an interval of at least 15 minutes. The shield outlives the interval.
            let endMinute = min(minute + 15, 23 * 60 + 59)
            let start = DateComponents(hour: minute / 60, minute: minute % 60)
            let end = DateComponents(hour: endMinute / 60, minute: endMinute % 60)
            try center.startMonitoring(DeviceActivityName("drink-\(minute)"),
                                       during: DeviceActivitySchedule(intervalStart: start,
                                                                      intervalEnd: end,
                                                                      repeats: true))
        }
    }
    #endif
}
