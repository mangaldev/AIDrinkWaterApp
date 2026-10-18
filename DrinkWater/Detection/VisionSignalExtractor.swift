import Vision
import CoreMedia

/// On-device signals from Apple's built-in Vision models (no model file to ship):
/// - face landmarks -> is there a face, and where the mouth is
/// - hand pose -> whether any of a hand is in view
/// - image classifier -> is a cup, mug, glass or bottle in view, and is it at the mouth
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
                s.mouthFound = true
            } else {
                // A cup often hides the lips; fall back to the lower part of the face box.
                s.mouth = CGPoint(x: box.midX, y: box.minY + box.height * 0.25)
            }
        }

        // Any finger joint counts, so a few fingers around a mug handle are enough.
        for hand in handRequest.results ?? [] {
            if let points = try? hand.recognizedPoints(.all) {
                s.handPoints += points.values.filter { $0.confidence > 0.2 }.map(\.location)
            }
        }

        // Look for a container in two kinds of places:
        // - at the mouth: a box on the mouth, and a box spanning the hand and mouth (a mug held by
        //   its handle sits between the fingers and the lips). This is the "cup covering your mouth" step.
        // - in view: the face area and the whole picture. This is the "I see a cup" step.
        if checkObjects, s.faceFound, let mouth = s.mouth {
            var all: [String: Float] = [:]       // everything seen, for the debug overlay
            var atMouthScores: [String: Float] = [:]   // only at the mouth, for learning
            for (roi, atMouth) in containerRegions(mouth: mouth, signals: s) {
                classifyRequest.regionOfInterest = roi
                try? handler.perform([classifyRequest])
                for obs in (classifyRequest.results ?? []).prefix(25) where obs.confidence > 0.08 {
                    all[obs.identifier] = max(all[obs.identifier] ?? 0, obs.confidence)
                    if atMouth, s.handNearMouth {
                        atMouthScores[obs.identifier] = max(atMouthScores[obs.identifier] ?? 0, obs.confidence)
                    }
                    guard profile.isContainer(obs.identifier, confidence: obs.confidence) else { continue }
                    s.containerInView = true
                    if atMouth, s.handNearMouth { s.containerAtMouth = true }
                }
            }
            s.mouthLabels = all.sorted { $0.value > $1.value }.prefix(5).map { "\($0.key) \(Int($0.value * 100))%" }
            for (label, score) in atMouthScores.sorted(by: { $0.value > $1.value }).prefix(20) {
                s.mouthLabelScores[label] = score
            }
        }
        return s
    }

    /// The areas to classify for a container, clipped to the frame. `true` marks an "at the mouth" area.
    private func containerRegions(mouth: CGPoint, signals s: FrameSignals) -> [(CGRect, Bool)] {
        let frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        var regions: [(CGRect, Bool)] = []

        // On the mouth.
        let side = min(max(s.faceWidth * 1.2, 0.15), 1)
        regions.append((CGRect(x: mouth.x - side / 2, y: mouth.y - side * 0.6, width: side, height: side), true))

        // Hand points near the mouth, plus the mouth itself, padded.
        let near = s.handPoints.filter { hypot($0.x - mouth.x, $0.y - mouth.y) < s.faceWidth * 0.9 } + [mouth]
        if near.count > 1 {
            let xs = near.map(\.x), ys = near.map(\.y)
            let pad = s.faceWidth * 0.3
            regions.append((CGRect(x: xs.min()! - pad, y: ys.min()! - pad,
                                   width: xs.max()! - xs.min()! + pad * 2,
                                   height: ys.max()! - ys.min()! + pad * 2), true))
        }

        // The face area, padded, and the whole picture.
        if s.faceWidth > 0 {
            let w = s.faceWidth * 2, h = s.faceHeight * 1.8
            regions.append((CGRect(x: mouth.x - w / 2, y: mouth.y - h * 0.45, width: w, height: h), false))
        }
        regions.append((frame, false))

        return regions
            .map { ($0.0.intersection(frame), $0.1) }
            .filter { !$0.0.isNull && $0.0.width > 0.05 && $0.0.height > 0.05 }
    }
}
