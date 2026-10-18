import Foundation
import UserNotifications

enum DrinkNotifications {
    /// Posts an immediate "open DrinkWater" notification. Used from the shield extensions,
    /// which cannot open the app themselves.
    static func postOpenAppNow() {
        let content = UNMutableNotificationContent()
        content.title = "Time to drink water"
        content.body = "Tap to open DrinkWater and unlock your phone."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let req = UNNotificationRequest(identifier: "drink-now",
                                        content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        UNUserNotificationCenter.current().add(req)
    }
}
