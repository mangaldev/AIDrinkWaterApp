import CoreGraphics
import CoreMedia

/// What one camera frame tells us. All points are Vision-normalized (0...1, origin bottom-left).
struct FrameSignals {
    var faceFound = false
    var mouth: CGPoint?
    var faceWidth: CGFloat = 0
    var faceHeight: CGFloat = 0
    var handPoints: [CGPoint] = []
    /// A bottle / cup / glass was recognized in the small area around the mouth.
    var containerAtMouth = false
    var headTiltedBack = false       // pitch suggests tipping the head back to drink
    /// Top labels the classifier saw around the mouth (shown in debug mode).
    var mouthLabels: [String] = []
    /// Every label seen around the mouth with its confidence (used for learning from feedback).
    var mouthLabelScores: [String: Float] = [:]

    /// Some of a hand is in view: even a couple of fingers on a mug handle is enough.
    var handFound: Bool { !handPoints.isEmpty }
}

/// Anything that turns a frame into signals. The default is `VisionSignalExtractor`;
/// a trained Core ML model can be dropped in behind the same shape later.
protocol SignalExtractor: AnyObject {
    /// Per-user tuning. Only read or set on the queue that calls `signals`.
    var profile: DetectionProfile { get set }
    func signals(for buffer: CMSampleBuffer, checkObjects: Bool) -> FrameSignals
}
