import Foundation
import CoreMedia

/// Decides "is this person drinking?" from a stream of frames.
///
/// Rule: face visible, a hand right at the mouth (not the forehead or cheek), and a bottle/cup/glass
/// recognized in the small area around the mouth in several frames. That has to hold for about
/// 1.5 seconds in total. A head tilt adds bonus progress. Which labels count as a container, and how
/// confident they must be, come from the user's `DetectionProfile`.
final class DrinkCheck: ObservableObject {
    @Published private(set) var progress: Double = 0
    @Published private(set) var hint = "Hold the phone so your face is in view, then take a sip."
    @Published private(set) var debugText = ""
    /// True once the check has run long enough that "I did drink" should be offered.
    @Published private(set) var offerManualConfirm = false

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
    private let offerConfirmAfter: TimeInterval = 15

    // Live state (touched only on `work`)
    private var sipSeconds: Double = 0
    private var containerFrames = 0
    private var lastAtMouth = Date.distantPast
    private var done = false
    private var startedAt = Date()

    // Session stats for learning (touched only on `work`)
    private var labelScores: [String: Float] = [:]
    private var secondsAtMouth: Double = 0
    private var framesSeen = 0
    private var framesWithFace = 0

    init(extractor: SignalExtractor = VisionSignalExtractor()) {
        self.extractor = extractor
    }

    /// Uses the latest learned profile for the frames that follow.
    func apply(_ profile: DetectionProfile) {
        work.async { self.extractor.profile = profile }
    }

    /// Starts over (after a 👎 or an "I did drink"), keeping the camera running.
    func reset() {
        work.async {
            self.sipSeconds = 0
            self.containerFrames = 0
            self.lastAtMouth = .distantPast
            self.done = false
            self.startedAt = Date()
            self.labelScores = [:]
            self.secondsAtMouth = 0
            self.framesSeen = 0
            self.framesWithFace = 0
            DispatchQueue.main.async {
                self.progress = 0
                self.offerManualConfirm = false
            }
        }
    }

    /// What this check saw so far, for saving with the user's feedback. Calls back on the main queue.
    func snapshot(outcome: CheckSample.Outcome, completion: @escaping (CheckSample) -> Void) {
        work.async {
            let sample = CheckSample(outcome: outcome,
                                     labelScores: self.labelScores,
                                     secondsAtMouth: self.secondsAtMouth,
                                     containerFrames: self.containerFrames,
                                     faceSeenRatio: self.framesSeen == 0 ? 0 : Double(self.framesWithFace) / Double(self.framesSeen))
            DispatchQueue.main.async { completion(sample) }
        }
    }

    /// Called from the camera queue for every frame. Throttled to `fps`.
    func process(_ buffer: CMSampleBuffer) {
        let now = Date()
        guard !busy, now.timeIntervalSince(lastProcessed) >= 1 / fps else { return }
        busy = true
        lastProcessed = now
        frameIndex += 1
        let checkObjects = frameIndex % 2 == 0   // classifier is the slowest request

        work.async { [weak self] in
            guard let self else { return }
            if !self.done {
                let s = self.extractor.signals(for: buffer, checkObjects: checkObjects)
                self.update(with: s, at: now)
            }
            self.busy = false
        }
    }

    private func update(with s: FrameSignals, at now: Date) {
        let step = 1 / fps
        let atMouth = s.faceFound && s.handFound

        framesSeen += 1
        if s.faceFound { framesWithFace += 1 }
        if atMouth {
            secondsAtMouth += step
            for (label, score) in s.mouthLabelScores where score > (labelScores[label] ?? 0) {
                labelScores[label] = score
            }
        }

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
        let offerConfirm = !verified && now.timeIntervalSince(startedAt) > offerConfirmAfter && secondsAtMouth > 1

        let newHint: String
        if verified { newHint = "Nice, logged a glass 💧" }
        else if !s.faceFound { newHint = "I can't see your face. Hold the phone in front of you." }
        else if !s.handFound { newHint = "I can't see your hand. Hold your glass or mug where I can see it." }
        else if !containerOK { newHint = "I see your face and hand. Now bring your glass, mug or bottle to your mouth." }
        else { newHint = "Keep drinking…" }

        let debug = "face \(s.faceFound ? "✓" : "✗")  hand \(s.handFound ? "✓" : "✗")  "
            + "glass \(containerFrames)/\(neededContainerFrames)  sip \(String(format: "%.1f", sipSeconds))s  "
            + "bar \(Int(extractor.profile.minConfidence * 100))%\n"
            + s.mouthLabels.joined(separator: ", ")

        if verified { done = true }   // stop processing further frames
        DispatchQueue.main.async {
            self.progress = shown
            self.hint = newHint
            self.debugText = debug
            self.offerManualConfirm = offerConfirm
            if verified { self.onVerified?() }
        }
    }
}
