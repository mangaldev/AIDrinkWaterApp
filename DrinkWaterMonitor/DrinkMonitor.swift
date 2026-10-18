import DeviceActivity
import Foundation

/// iOS wakes this extension at each scheduled reminder time, even if the app is closed.
/// It turns the shield on; only the app (after a successful drink check) turns it off.
class DrinkMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard SharedStore.schedule.enabled else { return }
        ShieldController.lock()
        DrinkNotifications.postOpenAppNow()
    }

    // Intentionally do nothing when the 15-minute interval ends:
    // the shield stays until the user drinks.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }
}
