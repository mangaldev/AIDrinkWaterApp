import SwiftUI
import UserNotifications
#if SCREEN_TIME
import FamilyControls
#endif

@MainActor
final class AppModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var isLocked = SharedStore.isLocked
    @Published var schedule = SharedStore.schedule
    @Published var errorMessage: String?
    #if SCREEN_TIME
    @Published var allowedApps = SharedStore.allowedApps
    #endif

    private var pollTimer: Timer?

    init() {
        refreshLockState()
        // Checks every few seconds whether a reminder has come due (or, in the paid build,
        // whether the monitor extension locked while the app was open).
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLockState() }
        }
    }

    func refreshLockState() {
        #if SCREEN_TIME
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        #else
        isAuthorized = SharedStore.onboarded
        #endif
        // A reminder passed without a drink: lock, even if the notification was ignored.
        if isAuthorized, !SharedStore.isLocked,
           SharedStore.schedule.isDue(lastCleared: SharedStore.lastCleared) {
            ShieldController.lock()
        }
        isLocked = SharedStore.isLocked
    }

    /// Asks for notifications (and, in the paid build, Screen Time access).
    func requestPermissions() async {
        do {
            #if SCREEN_TIME
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            #endif
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            SharedStore.onboarded = true
            saveSchedule()
        } catch {
            errorMessage = "Permission failed: \(error.localizedDescription)"
        }
        refreshLockState()
    }

    #if SCREEN_TIME
    func saveAllowedApps(_ sel: FamilyActivitySelection) {
        allowedApps = sel
        SharedStore.allowedApps = sel
    }
    #endif

    func saveSchedule() {
        SharedStore.schedule = schedule
        // A new schedule only counts from now on, so saving it doesn't lock you instantly.
        if !SharedStore.isLocked { SharedStore.lastCleared = Date() }
        do {
            try ReminderScheduler.apply(schedule)
        } catch {
            errorMessage = "Couldn't set schedule: \(error.localizedDescription)"
        }
    }

    /// Manual trigger for testing the lock without waiting for the schedule.
    func lockNow() {
        ShieldController.lock()
        refreshLockState()
    }

    func drinkVerified() {
        SharedStore.lastDrink = Date()
        ShieldController.unlock()
        refreshLockState()
    }

    func skip() {
        guard FeatureFlags.escapeHatchEnabled else { return }
        ShieldController.unlock()
        refreshLockState()
    }
}
