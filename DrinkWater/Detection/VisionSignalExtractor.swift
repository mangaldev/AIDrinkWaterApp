import Vision
import CoreMedia

/// On-device signals from Apple's built-in Vision models (no model file to ship):
/// - face landmarks -> where the mouth is, plus head pitch
/// - hand pose -> where fingertips and wrist are
/// - image classifier, run only on the area around the mouth -> is a bottle, cup or glass there
final class VisionSignalExtractor: SignalExtractor {
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 2
        return r
    }()
    private let classifyRequest = VNClassifyImageRequest()

    /// Words in Vision's built-in labels that count as a drink container.
    private let containerWords = ["bottle", "cup", "mug", "glass", "tumbler", "beverage", "drink", "straw", "flask", "jar"]
    /// Labels containing these words are ignored even if they match above (e.g. "eyeglasses").
    private let excludedWords = ["eyeglass", "sunglass", "glasses", "goggles", "window"]
    private let minContainerConfidence: Float = 0.25

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

        // Only look for a container when the hand is already at the mouth, and only in a small
        // box around the mouth, so a glass sitting on the desk doesn't count.
        if checkObjects, s.handAtMouth, let mouth = s.mouth {
            let side = min(max(s.faceWidth * 1.4, 0.15), 1)
            let roi = CGRect(x: mouth.x - side / 2, y: mouth.y - side * 0.65, width: side, height: side)
                .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            if !roi.isNull, roi.width > 0.05, roi.height > 0.05 {
                classifyRequest.regionOfInterest = roi
                try? handler.perform([classifyRequest])
                let labels = (classifyRequest.results ?? []).filter { $0.confidence > 0.1 }
                s.mouthLabels = labels.prefix(4).map { "\($0.identifier) \(Int($0.confidence * 100))%" }
                s.containerAtMouth = labels.contains { obs in
                    let id = obs.identifier.lowercased()
                    return obs.confidence >= minContainerConfidence
                        && containerWords.contains { id.contains($0) }
                        && !excludedWords.contains { id.contains($0) }
                }
            }
        }
        return s
    }
}
