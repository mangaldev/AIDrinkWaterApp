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

    /// A hand point is right at the mouth: close to it, and not above the upper lip.
    /// This is what rules out a hand on the forehead or cheek.
    var handAtMouth: Bool {
        guard let mouth, faceWidth > 0 else { return false }
        let maxDistance = faceWidth * 0.45
        let maxAbove = faceHeight * 0.12   // Vision y grows upward
        return handPoints.contains { p in
            hypot(p.x - mouth.x, p.y - mouth.y) < maxDistance && p.y < mouth.y + maxAbove
        }
    }
}

/// Anything that turns a frame into signals. The default is `VisionSignalExtractor`;
/// a trained Core ML model can be dropped in behind the same shape later.
protocol SignalExtractor {
    func signals(for buffer: CMSampleBuffer, checkObjects: Bool) -> FrameSignals
}
