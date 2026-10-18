import CoreGraphics
import CoreMedia

/// What one camera frame tells us. All points are Vision-normalized (0...1, origin bottom-left).
struct FrameSignals {
    var faceFound = false
    /// The lips were found by face landmarks (not just guessed from the face box).
    var mouthFound = false
    var mouth: CGPoint?
    var faceWidth: CGFloat = 0
    var faceHeight: CGFloat = 0
    var handPoints: [CGPoint] = []
    /// A cup, mug, glass or bottle was recognized anywhere around the face, hand or picture.
    var containerInView = false
    /// A cup, mug, glass or bottle was recognized right at the mouth, with a hand near it.
    var containerAtMouth = false
    /// Top labels the classifier saw around the mouth (shown in debug mode).
    var mouthLabels: [String] = []
    /// Every label seen around the mouth with its confidence (used for learning from feedback).
    var mouthLabelScores: [String: Float] = [:]

    /// Some of a hand is in view: even a couple of fingers on a mug handle is enough.
    var handFound: Bool { !handPoints.isEmpty }

    /// Some finger is near the mouth (a mug handle puts fingers off to the side, so this is generous).
    var handNearMouth: Bool {
        guard let mouth, faceWidth > 0 else { return false }
        return handPoints.contains { hypot($0.x - mouth.x, $0.y - mouth.y) < faceWidth * 0.9 }
    }
}

/// Anything that turns a frame into signals. The default is `VisionSignalExtractor`;
/// a trained Core ML model can be dropped in behind the same shape later.
protocol SignalExtractor: AnyObject {
    /// Per-user tuning. Only read or set on the queue that calls `signals`.
    var profile: DetectionProfile { get set }
    func signals(for buffer: CMSampleBuffer, checkObjects: Bool) -> FrameSignals
}
