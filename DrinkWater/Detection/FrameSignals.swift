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

    /// A hand point is near the mouth, and not up at the eyes or forehead.
    /// The distance is generous because a mug held by its handle puts the fingers off to the side
    /// of the face, often level with the nose. A hand on the forehead is still ruled out, and the
    /// check also needs a cup, bottle or glass seen at the mouth before it counts.
    var handAtMouth: Bool {
        guard let mouth, faceWidth > 0 else { return false }
        let maxDistance = faceWidth * 0.9
        let maxAbove = faceHeight * 0.35   // about nose level; Vision y grows upward
        return handPoints.contains { p in
            hypot(p.x - mouth.x, p.y - mouth.y) < maxDistance && p.y < mouth.y + maxAbove
        }
    }
}

/// Anything that turns a frame into signals. The default is `VisionSignalExtractor`;
/// a trained Core ML model can be dropped in behind the same shape later.
protocol SignalExtractor: AnyObject {
    /// Per-user tuning. Only read or set on the queue that calls `signals`.
    var profile: DetectionProfile { get set }
    func signals(for buffer: CMSampleBuffer, checkObjects: Bool) -> FrameSignals
}
