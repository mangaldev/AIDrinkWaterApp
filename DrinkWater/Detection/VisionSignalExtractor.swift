import Vision
import CoreMedia

/// On-device signals from Apple's built-in Vision models (no model file to ship):
/// - face landmarks -> where the mouth is, plus head pitch
/// - hand pose -> where fingertips and wrist are
/// - image classifier -> whether a bottle, cup or glass is in view
final class VisionSignalExtractor: SignalExtractor {
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 2
        return r
    }()
    private let classifyRequest = VNClassifyImageRequest()

    /// Labels from Vision's built-in taxonomy that count as a drink container.
    private let containerWords = ["bottle", "cup", "mug", "glass", "beverage", "drink", "water", "tumbler", "straw"]

    private let handJoints: [VNHumanHandPoseObservation.JointName] =
        [.thumbTip, .indexTip, .middleTip, .ringTip, .littleTip, .indexMCP, .middleMCP, .wrist]

    func signals(for buffer: CMSampleBuffer, checkObjects: Bool) -> FrameSignals {
        // Front camera in portrait delivers frames rotated; .leftMirrored puts the face upright.
        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .leftMirrored)
        var requests: [VNRequest] = [faceRequest, handRequest]
        if checkObjects { requests.append(classifyRequest) }
        try? handler.perform(requests)

        var s = FrameSignals()

        if let face = faceRequest.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) {
            s.faceFound = true
            let box = face.boundingBox
            s.faceWidth = box.width
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

        if checkObjects, let labels = classifyRequest.results {
            s.containerSeen = labels.contains { obs in
                obs.confidence > 0.2 && containerWords.contains { obs.identifier.lowercased().contains($0) }
            }
        }
        return s
    }
}
