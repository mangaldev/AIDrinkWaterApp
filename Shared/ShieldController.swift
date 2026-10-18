import Foundation
#if SCREEN_TIME
import ManagedSettings
#endif

/// Turns the lock on and off.
/// Paid build (SCREEN_TIME): shields every other app too.
/// Free build: only DrinkWater's own full-screen check is shown.
enum ShieldController {
    #if SCREEN_TIME
    static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("drinkwater"))
    #endif

    static func lock() {
        #if SCREEN_TIME
        let allowed = SharedStore.allowedApps
        store.shield.applicationCategories = .all(except: allowed.applicationTokens)
        store.shield.webDomainCategories = .all(except: allowed.webDomainTokens)
        #endif
        if !SharedStore.isLocked { SharedStore.lockedSince = Date() }
        SharedStore.isLocked = true
    }

    static func unlock() {
        #if SCREEN_TIME
        store.clearAllSettings()
        #endif
        SharedStore.isLocked = false
        SharedStore.lockedSince = nil
        SharedStore.lastCleared = Date()
    }
}
