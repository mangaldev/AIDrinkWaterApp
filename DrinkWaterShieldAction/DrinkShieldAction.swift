import ManagedSettings
import Foundation

/// Handles the "Open DrinkWater" button on the shield. Shield extensions can't launch apps,
/// so we post a notification the user taps to jump straight into the drink check.
class DrinkShieldAction: ShieldActionDelegate {
    override func handle(action: ManagedSettings.ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ManagedSettings.ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ManagedSettings.ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    private func respond(_ action: ManagedSettings.ShieldAction, _ done: (ShieldActionResponse) -> Void) {
        if action == .primaryButtonPressed { DrinkNotifications.postOpenAppNow() }
        done(.close)
    }
}
