import SwiftUI

/// Settings section showing what the drink check has learned from your feedback.
@MainActor
struct LearningSection: View {
    @ObservedObject private var learner = DetectionLearner.shared
    @State private var confirmReset = false

    var body: some View {
        Section {
            LabeledContent("Feedback given", value: "\(learner.samples.filter { $0.feedback != .none }.count)")
            LabeledContent("Missed drinks reported", value: "\(learner.missedCount)")
            LabeledContent("Wrong passes reported", value: "\(learner.wrongCount)")
            LabeledContent("Confidence needed", value: "\(Int(learner.profile.minConfidence * 100))%")
            if !learner.profile.learnedLabels.isEmpty {
                LabeledContent("Learned as your cup",
                               value: learner.profile.learnedLabels.sorted().joined(separator: ", "))
            }
            Button("Reset learning", role: .destructive) { confirmReset = true }
                .confirmationDialog("Forget everything the drink check learned?",
                                    isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) { learner.reset() }
                }
        } header: {
            Text("Drink check learning")
        } footer: {
            Text("After a check, tell it whether you really drank, or tap \"I did drink\" if it missed you. It tunes itself to your cups and lighting. Learning happens only on this iPhone and keeps label names and numbers, never images.")
        }
    }
}
