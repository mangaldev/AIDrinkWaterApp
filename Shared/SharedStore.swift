import Foundation
#if SCREEN_TIME
import FamilyControls
#endif

/// State shared between the app and its extensions through the App Group.
/// Change the group id here and in every .entitlements file if you change the bundle id.
enum SharedStore {
    static let appGroupID = "group.com.example.drinkwater"
    static var defaults: UserDefaults {
        #if SCREEN_TIME
        UserDefaults(suiteName: appGroupID) ?? .standard
        #else
        .standard   // free build has no App Group and no extensions
        #endif
    }

    private enum Key {
        static let isLocked = "isLocked"
        static let lockedSince = "lockedSince"
        static let allowedApps = "allowedApps"
        static let schedule = "schedule"
        static let lastDrink = "lastDrink"
        static let lastCleared = "lastCleared"
        static let onboarded = "onboarded"
    }

    /// True while a drink check is pending and other apps are shielded.
    static var isLocked: Bool {
        get { defaults.bool(forKey: Key.isLocked) }
        set { defaults.set(newValue, forKey: Key.isLocked) }
    }

    static var lockedSince: Date? {
        get { defaults.object(forKey: Key.lockedSince) as? Date }
        set { defaults.set(newValue, forKey: Key.lockedSince) }
    }

    static var lastDrink: Date? {
        get { defaults.object(forKey: Key.lastDrink) as? Date }
        set { defaults.set(newValue, forKey: Key.lastDrink) }
    }

    /// Last time the lock was lifted (drink or skip). Reminders before this are already handled.
    static var lastCleared: Date? {
        get { defaults.object(forKey: Key.lastCleared) as? Date }
        set { defaults.set(newValue, forKey: Key.lastCleared) }
    }

    static var onboarded: Bool {
        get { defaults.bool(forKey: Key.onboarded) }
        set { defaults.set(newValue, forKey: Key.onboarded) }
    }

    #if SCREEN_TIME
    /// Apps that stay usable during a lock (pick DrinkWater itself, Phone, Messages...).
    static var allowedApps: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: Key.allowedApps),
                  let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return sel
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.allowedApps) }
    }
    #endif

    static var schedule: ReminderSchedule {
        get {
            guard let data = defaults.data(forKey: Key.schedule),
                  let s = try? JSONDecoder().decode(ReminderSchedule.self, from: data)
            else { return ReminderSchedule() }
            return s
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.schedule) }
    }
}
