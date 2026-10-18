import Foundation
import CoreMedia

/// Decides "is this person drinking?" from a stream of frames.
///
/// Rule: face visible, a hand right at the mouth (not the forehead or cheek), and a bottle/cup/glass
/// recognized in the small area around the mouth in several frames. That has to hold for about
/// 1.5 seconds in total. A head tilt adds bonus progress.
final class DrinkCheck: ObservableObject {
    @Published private(set) var progress: Double = 0
    @Published private(set) var hint = "Hold the phone so your face is in view, then take a sip."
    @Published private(set) var debugText = ""

    var onVerified: (() -> Void)?

    private let extractor: SignalExtractor
    private let work = DispatchQueue(label: "drinkwater.vision")
    private var busy = false
    private var frameIndex = 0
    private var lastProcessed = Date.distantPast

    // Tunables
    private let fps: Double = 10
    private let neededSipSeconds: Double = 1.5
    private let neededContainerFrames = 3        // classifier must agree this many times
    private let forgetAfter: TimeInterval = 3    // lose progress if you stop for this long

    private var sipSeconds: Double = 0
    private var containerFrames = 0
    private var lastAtMouth = Date.distantPast
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
        let checkObjects = frameIndex % 2 == 0   // classifier is the slowest request

        work.async { [weak self] in
            guard let self else { return }
            let s = self.extractor.signals(for: buffer, checkObjects: checkObjects)
            self.update(with: s, at: now)
            self.busy = false
        }
    }

    private func update(with s: FrameSignals, at now: Date) {
        let step = 1 / fps
        let atMouth = s.faceFound && s.handAtMouth

        if atMouth {
            lastAtMouth = now
            if s.containerAtMouth { containerFrames += 1 }
            // Progress only builds once the container has been confirmed.
            if containerFrames >= neededContainerFrames {
                sipSeconds += s.headTiltedBack ? step * 1.5 : step
            }
        } else if now.timeIntervalSince(lastAtMouth) > forgetAfter {
            sipSeconds = 0
            containerFrames = 0
        }

        let containerOK = containerFrames >= neededContainerFrames
        let ratio = min(sipSeconds / neededSipSeconds, 1)
        // Show a little progress for hand-at-mouth so it doesn't feel stuck, but cap it.
        let shown = containerOK ? 0.2 + 0.8 * ratio : (atMouth ? 0.15 : 0)
        let verified = containerOK && ratio >= 1

        let newHint: String
        if verified { newHint = "Nice, logged a glass 💧" }
        else if !s.faceFound { newHint = "I can't see your face. Hold the phone in front of you." }
        else if !s.handAtMouth { newHint = "Bring your glass or bottle to your mouth and take a sip." }
        else if !containerOK { newHint = "I see your hand, but not a glass. Keep the glass or bottle in view." }
        else { newHint = "Keep drinking…" }

        let debug = "face \(s.faceFound ? "✓" : "✗")  hand@mouth \(s.handAtMouth ? "✓" : "✗")  "
            + "glass \(containerFrames)/\(neededContainerFrames)  sip \(String(format: "%.1f", sipSeconds))s\n"
            + s.mouthLabels.joined(separator: ", ")

        if verified { done = true }   // stop processing further frames
        DispatchQueue.main.async {
            self.progress = shown
            self.hint = newHint
            self.debugText = debug
            if verified { self.onVerified?() }
        }
    }
}
