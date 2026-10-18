import AVFoundation
import AudioToolbox

/// Plays the reminder alert while the app is open: three vibrations and/or the chosen sound.
/// (A notification arriving in the background can only vibrate once; that part is up to iOS.)
@MainActor
enum AlertPlayer {
    private static var player: AVAudioPlayer?

    static func playReminderAlert(_ settings: AlertSettings = SharedStore.alerts) {
        if settings.vibrate { vibrate(times: 3) }
        if settings.soundEnabled { play(settings.sound) }
    }

    /// Vibrates `times` times, about 0.7 s apart.
    static func vibrate(times: Int = 3) {
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 * Double(i)) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }

    static func play(_ sound: AlertSettings.Sound) {
        guard let file = sound.fileName,
              let url = Bundle.main.url(forResource: (file as NSString).deletingPathExtension, withExtension: "wav")
        else {
            AudioServicesPlaySystemSound(1007)   // the standard "tri-tone"-style alert
            return
        }
        // .ambient respects the silent switch, like a notification would.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
