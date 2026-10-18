import Foundation
import CoreMedia

/// Decides "is this person drinking?" from a stream of frames, as five steps shown to the user:
///
/// 1. Face detected
/// 2. Mouth detected
/// 3. Cup, mug or glass detected
/// 4. Hand or fingers detected
/// 5. Cup at your mouth (seen right at the mouth with a finger near it, in 2 frames)
///
/// Steps 1 to 4 turn green the first time they're seen and stay green, so the check doesn't flicker
/// or start over when the cup briefly hides your face. Step 5 only counts once 1 to 4 are green.
/// When all five are green, the drink counts. Which labels count as a container, and how confident
/// they must be, come from the user's `DetectionProfile`.
final class DrinkCheck: ObservableObject {
    enum Step: Int, CaseIterable, Identifiable {
        case face, mouth, cup, hand, cupAtMouth
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .face: return "Face detected"
            case .mouth: return "Mouth detected"
            case .cup: return "Cup, mug or glass detected"
            case .hand: return "Hand or fingers detected"
            case .cupAtMouth: return "Cup at your mouth"
            }
        }
    }

    /// Which steps are green, in order.
    @Published private(set) var passed: [Bool] = Array(repeating: false, count: Step.allCases.count)
    @Published private(set) var progress: Double = 0
    @Published private(set) var hint = "Hold the phone so your face is in view."
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
    private let neededAtMouthFrames = 2          // classifier must see the cup at the mouth this many times
    private let offerConfirmAfter: TimeInterval = 15

    // Live state (touched only on `work`)
    private var seen = Set<Step>()
    private var atMouthFrames = 0
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
            self.seen = []
            self.atMouthFrames = 0
            self.done = false
            self.startedAt = Date()
            self.labelScores = [:]
            self.secondsAtMouth = 0
            self.framesSeen = 0
            self.framesWithFace = 0
            DispatchQueue.main.async {
                self.passed = Array(repeating: false, count: Step.allCases.count)
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
                                     containerFrames: self.atMouthFrames,
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

        framesSeen += 1
        if s.faceFound { framesWithFace += 1 }
        if s.faceFound && s.handNearMouth {
            secondsAtMouth += step
            for (label, score) in s.mouthLabelScores where score > (labelScores[label] ?? 0) {
                labelScores[label] = score
            }
        }

        if s.faceFound { seen.insert(.face) }
        if s.mouthFound { seen.insert(.mouth) }
        if s.containerInView || s.containerAtMouth { seen.insert(.cup) }
        if s.handFound { seen.insert(.hand) }

        let firstFour: Set<Step> = [.face, .mouth, .cup, .hand]
        if firstFour.isSubset(of: seen), s.faceFound, s.containerAtMouth {
            atMouthFrames += 1
            if atMouthFrames >= neededAtMouthFrames { seen.insert(.cupAtMouth) }
        }

        let passedNow = Step.allCases.map { seen.contains($0) }
        let verified = passedNow.allSatisfy { $0 }
        let firstMissing = Step.allCases.first { !seen.contains($0) }
        let offerConfirm = !verified && now.timeIntervalSince(startedAt) > offerConfirmAfter && seen.count >= 3

        let newHint: String
        switch firstMissing {
        case nil: newHint = "Nice, logged a glass 💧"
        case .face?: newHint = "Hold the phone so your face is in view."
        case .mouth?: newHint = "Keep your mouth in view for a moment."
        case .cup?: newHint = "Show me your cup, mug, glass or bottle."
        case .hand?: newHint = "Hold your cup so I can see your hand or fingers."
        case .cupAtMouth?: newHint = "Now bring it to your mouth and take a sip."
        }

        let debug = "face \(s.faceFound ? "✓" : "✗")  mouth \(s.mouthFound ? "✓" : "✗")  "
            + "cup \(s.containerInView ? "✓" : "✗")  hand \(s.handFound ? "✓" : "✗")  "
            + "at mouth \(atMouthFrames)/\(neededAtMouthFrames)  bar \(Int(extractor.profile.minConfidence * 100))%\n"
            + s.mouthLabels.joined(separator: ", ")

        if verified { done = true }   // stop processing further frames
        DispatchQueue.main.async {
            self.passed = passedNow
            self.progress = Double(passedNow.filter { $0 }.count) / Double(passedNow.count)
            self.hint = newHint
            self.debugText = debug
            self.offerManualConfirm = offerConfirm
            if verified { self.onVerified?() }
        }
    }
}
