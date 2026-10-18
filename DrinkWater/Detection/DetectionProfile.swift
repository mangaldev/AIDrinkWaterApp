import Foundation

/// The per-user tuning the drink check applies on top of Apple's built-in Vision model.
/// It starts with sensible defaults and is adjusted by `DetectionLearner` from the user's feedback.
/// Everything stays on the phone.
struct DetectionProfile: Codable, Equatable {
    /// Words in Vision's labels that count as a drink container.
    /// Matched anywhere in the label, so "coffee_mug" and "water_bottle" count.
    static let baseContainerWords = ["bottle", "cup", "mug", "glass", "tumbler", "beverage", "drink",
                                     "straw", "flask", "jar", "coffee", "tea", "thermos", "canteen",
                                     "tableware", "dishware", "drinkware", "porcelain", "ceramic"]
    /// Matched only as a whole word, because they are short ("can" is in "candle").
    static let baseContainerTokens = ["can", "kettle", "pitcher", "jug", "carafe", "container"]
    /// Never count these, even if they contain a container word (e.g. "eyeglasses", "cupcake").
    static let baseExcludedWords = ["eyeglass", "sunglass", "glasses", "goggles", "window", "cupcake", "teeth"]
    /// Labels about people and bodies. Never learned as a container, or a hand on the mouth would pass.
    static let bodyWords = ["person", "people", "adult", "child", "baby", "face", "head", "hand", "finger",
                            "arm", "skin", "portrait", "selfie", "hair", "beard", "mouth", "lip", "nose",
                            "eye", "ear", "clothing", "shirt", "human"]

    static let defaultMinConfidence: Float = 0.25
    static let lowestMinConfidence: Float = 0.12
    static let highestMinConfidence: Float = 0.5

    /// Exact labels learned to mean "drink container" for this user (e.g. "kettle").
    var learnedLabels: Set<String> = []
    /// Exact labels learned to NOT mean a container for this user (after a 👎).
    var blockedLabels: Set<String> = []
    /// How sure the classifier must be that a container is at the mouth.
    var minConfidence: Float = defaultMinConfidence

    /// Does this label (with its confidence) count as a drink container at the mouth?
    func isContainer(_ label: String, confidence: Float) -> Bool {
        let id = label.lowercased()
        guard confidence >= minConfidence, !blockedLabels.contains(id) else { return false }
        if learnedLabels.contains(id) { return true }
        let tokens = id.split(whereSeparator: { !$0.isLetter }).map(String.init)
        let matches = Self.baseContainerWords.contains { id.contains($0) }
            || tokens.contains { Self.baseContainerTokens.contains($0) }
        return matches && !Self.baseExcludedWords.contains { id.contains($0) }
    }

    static func isBodyLabel(_ label: String) -> Bool {
        let id = label.lowercased()
        return bodyWords.contains { id.contains($0) }
    }
}

/// What one camera check saw, saved with the user's feedback. Only numbers and label names:
/// no images are ever kept.
struct CheckSample: Codable, Identifiable {
    enum Outcome: String, Codable {
        case passed          // the check passed
        case userSaysDrank   // check didn't pass; user tapped "I did drink"
    }
    enum Feedback: String, Codable {
        case correct         // 👍 after a pass, or confirmed "I did drink"
        case wrong           // 👎: it passed but the user wasn't drinking
        case none
    }

    var id = UUID()
    var date = Date()
    var outcome: Outcome
    var feedback: Feedback = .none
    /// Highest confidence each label reached near the mouth while the hand was there.
    var labelScores: [String: Float] = [:]
    var secondsAtMouth: Double = 0
    var containerFrames = 0
    var faceSeenRatio: Double = 0
}

/// Stores samples and turns feedback into a better `DetectionProfile`.
///
/// Rules (simple on purpose, so the behavior is predictable):
/// - "I did drink": labels that showed up near your mouth (not body labels) are remembered.
///   A label seen in 2 such checks becomes a container for you. If a known container was seen
///   but below the bar, the bar is lowered to just under it (never below 0.12).
/// - 👎 after a pass: the labels that made it pass are blocked if they were learned, and the
///   confidence bar goes up a little (never above 0.5).
/// - 👍 after a pass: kept as a good example; nothing changes.
@MainActor
final class DetectionLearner: ObservableObject {
    static let shared = DetectionLearner()

    @Published private(set) var profile: DetectionProfile
    @Published private(set) var samples: [CheckSample]

    private let profileKey = "detectionProfile"
    private let samplesKey = "detectionSamples"
    private let maxSamples = 200
    private let timesBeforeLearning = 2

    private var defaults: UserDefaults { SharedStore.defaults }

    private init() {
        let d = SharedStore.defaults
        profile = (d.data(forKey: profileKey)).flatMap { try? JSONDecoder().decode(DetectionProfile.self, from: $0) }
            ?? DetectionProfile()
        samples = (d.data(forKey: samplesKey)).flatMap { try? JSONDecoder().decode([CheckSample].self, from: $0) }
            ?? []
    }

    var goodCount: Int { samples.filter { $0.feedback == .correct }.count }
    var wrongCount: Int { samples.filter { $0.feedback == .wrong }.count }
    var missedCount: Int { samples.filter { $0.outcome == .userSaysDrank }.count }

    /// Records a check and its feedback, and updates the profile. Returns what changed, for the UI.
    @discardableResult
    func record(_ sample: CheckSample) -> String? {
        samples.insert(sample, at: 0)
        if samples.count > maxSamples { samples.removeLast(samples.count - maxSamples) }

        var p = profile
        var note: String?

        switch (sample.outcome, sample.feedback) {
        case (.userSaysDrank, _):
            // Lower the bar if a known container was there but not confident enough.
            let knownScores = sample.labelScores.filter { p.isContainer($0.key, confidence: 1) }.map(\.value)
            if let best = knownScores.max(), best < p.minConfidence, best >= DetectionProfile.lowestMinConfidence {
                p.minConfidence = max(DetectionProfile.lowestMinConfidence, best * 0.9)
                note = "Got it. I'll accept a less certain match next time."
            }
            // Learn labels that keep showing up when the user says they drank.
            let candidates = sample.labelScores.keys
                .map { $0.lowercased() }
                .filter { !DetectionProfile.isBodyLabel($0) && !p.isContainer($0, confidence: 1) }
            for label in candidates where !p.blockedLabels.contains(label) {
                let times = samples.filter { $0.outcome == .userSaysDrank && $0.labelScores.keys.contains { $0.lowercased() == label } }.count
                if times >= timesBeforeLearning {
                    p.learnedLabels.insert(label)
                    note = "Learned: I'll treat \"\(label)\" as your cup from now on."
                }
            }
            if note == nil { note = "Thanks. Try another sip; I'm learning what your cup looks like." }

        case (.passed, .wrong):
            let matched = sample.labelScores.filter { p.isContainer($0.key, confidence: $0.value) }.map { $0.key.lowercased() }
            for label in matched where p.learnedLabels.contains(label) {
                p.learnedLabels.remove(label)
                p.blockedLabels.insert(label)
            }
            p.minConfidence = min(DetectionProfile.highestMinConfidence, p.minConfidence + 0.05)
            note = "Thanks. I'll be stricter next time."

        case (.passed, _):
            break
        }

        profile = p
        save()
        return note
    }

    func reset() {
        profile = DetectionProfile()
        samples = []
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(profile), forKey: profileKey)
        defaults.set(try? JSONEncoder().encode(samples), forKey: samplesKey)
    }
}
