import Foundation
import CoreMedia

/// Decides "is this person drinking?" from a stream of frames.
///
/// Rule: within a rolling window, the hand must be at the mouth for about 1.5 seconds in total,
/// the face must stay visible, and a bottle/cup/glass must be seen at least once near the mouth.
/// A head tilt adds bonus progress. This beats a single photo, which is easy to fake.
final class DrinkCheck: ObservableObject {
    @Published private(set) var progress: Double = 0
    @Published private(set) var hint = "Hold the phone so your face is in view, then take a sip."

    var onVerified: (() -> Void)?

    private let extractor: SignalExtractor
    private let work = DispatchQueue(label: "drinkwater.vision")
    private var busy = false
    private var frameIndex = 0
    private var lastProcessed = Date.distantPast

    // Tunables
    private let fps: Double = 10
    private let neededSipSeconds: Double = 1.5
    private let forgetAfter: TimeInterval = 4      // lose progress if you stop for this long

    private var sipSeconds: Double = 0
    private var containerSeenRecently = false
    private var lastNearMouth = Date.distantPast
    private var done = false

    init(extractor: SignalExtractor = VisionSignalExtractor()) {
        self.extractor = extractor
    }

    /// Called from the camera queue for every frame. Throttled to `fps`.
    func process(_ buffer: CMSampleBuffer) {
        let now = Date()
        guard !done, !busy, now.timeIntervalSince(lastProcessed) >= 1 / fps else { return }
        busy = true
        lastProcessed = now
        frameIndex += 1
        let checkObjects = frameIndex % 3 == 0   // classifier is the slowest request

        work.async { [weak self] in
            guard let self else { return }
            let s = self.extractor.signals(for: buffer, checkObjects: checkObjects)
            self.update(with: s, at: now)
            self.busy = false
        }
    }

    private func update(with s: FrameSignals, at now: Date) {
        let step = 1 / fps

        if s.handNearMouth {
            lastNearMouth = now
            sipSeconds += s.headTiltedBack ? step * 1.5 : step
            if s.containerSeen { containerSeenRecently = true }
        } else if now.timeIntervalSince(lastNearMouth) > forgetAfter {
            sipSeconds = 0
            containerSeenRecently = false
        }

        let ratio = min(sipSeconds / neededSipSeconds, 1)
        // Without a container seen, cap progress so a hand alone can't unlock.
        let shown = containerSeenRecently ? ratio : min(ratio, 0.6)
        let verified = ratio >= 1 && containerSeenRecently && s.faceFound

        let newHint: String
        if verified { newHint = "Nice, unlocked 💧" }
        else if !s.faceFound { newHint = "I can't see your face. Hold the phone in front of you." }
        else if !s.handNearMouth { newHint = "Bring your water to your mouth and take a sip." }
        else if !containerSeenRecently { newHint = "Keep drinking, and make sure the bottle or glass is visible." }
        else { newHint = "Keep drinking…" }

        if verified { done = true }   // stop processing further frames
        DispatchQueue.main.async {
            self.progress = shown
            self.hint = newHint
            if verified { self.onVerified?() }
        }
    }
}
