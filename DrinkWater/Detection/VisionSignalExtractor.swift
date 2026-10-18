import Vision
import CoreMedia

/// On-device signals from Apple's built-in Vision models (no model file to ship):
/// - face landmarks -> where the mouth is, plus head pitch
/// - hand pose -> where fingertips and wrist are
/// - image classifier, run only on the area around the mouth and hand -> is a bottle, cup, mug or glass there
final class VisionSignalExtractor: SignalExtractor {
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 2
        return r
    }()
    private let classifyRequest = VNClassifyImageRequest()

    /// Which labels count as a container, and how confident they must be. Learned per user.
    var profile: DetectionProfile

    init(profile: DetectionProfile = DetectionProfile()) {
        self.profile = profile
    }

    private let handJoints: [VNHumanHandPoseObservation.JointName] =
        [.thumbTip, .indexTip, .middleTip, .ringTip, .littleTip, .thumbIP, .indexPIP, .middlePIP]

    func signals(for buffer: CMSampleBuffer, checkObjects: Bool) -> FrameSignals {
        // Front camera in portrait delivers frames rotated; .leftMirrored puts the face upright.
        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .leftMirrored)
        try? handler.perform([faceRequest, handRequest])

        var s = FrameSignals()

        if let face = faceRequest.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) {
            s.faceFound = true
            let box = face.boundingBox
            s.faceWidth = box.width
            s.faceHeight = box.height
            if let lips = face.landmarks?.outerLips, lips.pointCount > 0 {
                let pts = lips.normalizedPoints   // relative to the face box
                let cx = pts.map(\.x).reduce(0, +) / CGFloat(pts.count)
                let cy = pts.map(\.y).reduce(0, +) / CGFloat(pts.count)
                s.mouth = CGPoint(x: box.minX + cx * box.width, y: box.minY + cy * box.height)
            } else {
                // A cup often hides the lips; fall back to the lower part of the face box.
                s.mouth = CGPoint(x: box.midX, y: box.minY + box.height * 0.25)
            }
            if let pitch = face.pitch?.doubleValue {
                s.headTiltedBack = pitch < -0.15   // radians; negative = chin up
            }
        }

        for hand in handRequest.results ?? [] {
            for joint in handJoints {
                if let p = try? hand.recognizedPoint(joint), p.confidence > 0.3 {
                    s.handPoints.append(p.location)
                }
            }
        }

        // Only look for a container when the hand is already at the mouth, and only near the mouth,
        // so a glass sitting on the desk doesn't count. Two areas are checked:
        // 1. a box around the mouth;
        // 2. a box around the hand and mouth together. A mug held by its handle sits between the
        //    fingers and the lips, and when you tip it up the camera sees its base, off to one side.
        if checkObjects, s.handAtMouth, let mouth = s.mouth {
            var scores: [String: Float] = [:]
            for roi in containerRegions(mouth: mouth, signals: s) {
                classifyRequest.regionOfInterest = roi
                try? handler.perform([classifyRequest])
                for obs in (classifyRequest.results ?? []).prefix(25) where obs.confidence > 0.08 {
                    scores[obs.identifier] = max(scores[obs.identifier] ?? 0, obs.confidence)
                }
            }
            let ranked = scores.sorted { $0.value > $1.value }
            s.mouthLabels = ranked.prefix(5).map { "\($0.key) \(Int($0.value * 100))%" }
            for (label, score) in ranked.prefix(20) { s.mouthLabelScores[label] = score }
            s.containerAtMouth = ranked.contains { profile.isContainer($0.key, confidence: $0.value) }
        }
        return s
    }

    /// The areas to classify for a container, clipped to the frame.
    private func containerRegions(mouth: CGPoint, signals s: FrameSignals) -> [CGRect] {
        let frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        var regions: [CGRect] = []

        let side = min(max(s.faceWidth * 1.4, 0.15), 1)
        regions.append(CGRect(x: mouth.x - side / 2, y: mouth.y - side * 0.65, width: side, height: side))

        // Hand points near the mouth, plus the mouth itself, padded.
        let near = s.handPoints.filter { hypot($0.x - mouth.x, $0.y - mouth.y) < s.faceWidth * 0.9 } + [mouth]
        if near.count > 1 {
            let xs = near.map(\.x), ys = near.map(\.y)
            let pad = s.faceWidth * 0.35
            regions.append(CGRect(x: xs.min()! - pad, y: ys.min()! - pad,
                                  width: xs.max()! - xs.min()! + pad * 2,
                                  height: ys.max()! - ys.min()! + pad * 2))
        }

        return regions
            .map { $0.intersection(frame) }
            .filter { !$0.isNull && $0.width > 0.05 && $0.height > 0.05 }
    }
}
