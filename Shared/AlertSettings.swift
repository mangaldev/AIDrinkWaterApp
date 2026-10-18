import Foundation
import UserNotifications

/// How reminders get your attention. Default: vibrate on, sound off.
struct AlertSettings: Codable, Equatable {
    enum Sound: String, Codable, CaseIterable, Identifiable {
        case waterDrop = "water_drop"
        case chime
        case bell
        case systemDefault = "default"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .waterDrop: return "Water drop"
            case .chime: return "Chime"
            case .bell: return "Bell"
            case .systemDefault: return "iPhone default"
            }
        }

        /// File in DrinkWater/Sounds, or nil for the system sound.
        var fileName: String? { self == .systemDefault ? nil : "\(rawValue).wav" }
    }

    var vibrate = true
    var soundEnabled = false
    var sound: Sound = .waterDrop

    /// The sound to attach to a reminder notification.
    ///
    /// iOS vibrates when a notification plays a sound (if the phone's haptics are on), so
    /// "vibrate, no sound" uses a silent sound file. With both off the reminder arrives silently.
    var notificationSound: UNNotificationSound? {
        if soundEnabled {
            if let file = sound.fileName { return UNNotificationSound(named: UNNotificationSoundName(file)) }
            return .default
        }
        return vibrate ? UNNotificationSound(named: UNNotificationSoundName("silence.wav")) : nil
    }
}

extension SharedStore {
    private static let alertKey = "alertSettings"

    static var alerts: AlertSettings {
        get {
            guard let data = defaults.data(forKey: alertKey),
                  let s = try? JSONDecoder().decode(AlertSettings.self, from: data)
            else { return AlertSettings() }
            return s
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: alertKey) }
    }
}
