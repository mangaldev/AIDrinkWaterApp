import CoreGraphics
import CoreMedia

/// What one camera frame tells us. All points are Vision-normalized (0...1, origin bottom-left).
struct FrameSignals {
    var faceFound = false
    var mouth: CGPoint?
    var faceWidth: CGFloat = 0
    var handPoints: [CGPoint] = []
    var containerSeen = false        // bottle / cup / glass seen in this frame
    var headTiltedBack = false       // pitch suggests tipping the head back to drink

    /// Hand (fingertips or wrist) close to the mouth, relative to face size.
    var handNearMouth: Bool {
        guard let mouth, faceWidth > 0 else { return false }
        let limit = faceWidth * 0.75
        return handPoints.contains { hypot($0.x - mouth.x, $0.y - mouth.y) < limit }
    }
}

/// Anything that turns a frame into signals. The default is `VisionSignalExtractor`;
/// a trained Core ML model can be dropped in behind the same shape later.
protocol SignalExtractor {
    func signals(for buffer: CMSampleBuffer, checkObjects: Bool) -> FrameSignals
}
