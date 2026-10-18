import SwiftUI

/// Full-screen camera check.
/// - `.reminder`: shown while a reminder is due; can only be left by drinking (or Skip, if enabled).
/// - `.manual`: opened from "Add a glass"; has a Cancel button.
///
/// After a pass it asks "Did you just drink?" and, if the check is stuck, offers "I did drink".
/// Both answers teach `DetectionLearner`, on this phone only.
@MainActor
struct DrinkCheckView: View {
    enum Mode { case reminder, manual }
    private enum Phase { case checking, askFeedback }

    let mode: Mode
    var onClose: (() -> Void)? = nil

    @EnvironmentObject var model: AppModel
    @StateObject private var camera = CameraSession()
    @StateObject private var checker = DrinkCheck()
    @ObservedObject private var learner = DetectionLearner.shared
    @AppStorage("showDetectionDebug") private var showDebug = false
    @State private var phase: Phase = .checking
    @State private var learnedNote: String?
    @State private var pendingSample: CheckSample?

    /// How long "Did you just drink?" waits before counting the glass anyway.
    private let feedbackTimeout: UInt64 = 6

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()

            VStack(spacing: 16) {
                Text(mode == .reminder ? "Time to drink water" : "Add a glass")
                    .font(.title.bold())
                    .padding(.top, 40)
                PrivacyBadge()
                Text(phase == .askFeedback ? "Did you just drink?" : checker.hint)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if phase == .checking {
                    StepList(passed: checker.passed)
                }

                if let learnedNote {
                    Text(learnedNote)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .background(.blue.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                        .transition(.opacity)
                }

                if showDebug && FeatureFlags.testingTools {
                    Text(checker.debugText)
                        .font(.caption.monospaced())
                        .padding(8)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                switch phase {
                case .askFeedback:
                    feedbackButtons
                case .checking:
                    if checker.offerManualConfirm {
                        Button("I did drink, it didn't notice") { userSaysDrank() }
                            .buttonStyle(.borderedProminent)
                    }
                    bottomButton
                }
            }
            .foregroundStyle(.white)
            .shadow(radius: 4)
        }
        .background(Color.black)
        .animation(.default, value: learnedNote)
        .onTapGesture(count: 3) {   // triple-tap shows what the detector sees (Debug builds only)
            if FeatureFlags.testingTools { showDebug.toggle() }
        }
        .onAppear {
            checker.apply(learner.profile)
            checker.onVerified = { checkPassed() }
            camera.onFrame = { [weak checker] buffer in checker?.process(buffer) }
            // Alert before the camera starts: iOS can mute vibration while capture is running.
            if mode == .reminder { AlertPlayer.playReminderAlert() }
            camera.start()
        }
        .onDisappear { camera.stop() }
    }

    // MARK: Pieces

    private var feedbackButtons: some View {
        HStack(spacing: 16) {
            Button { answer(correct: true) } label: {
                Label("Yes", systemImage: "hand.thumbsup.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button { answer(correct: false) } label: {
                Label("No", systemImage: "hand.thumbsdown.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .controlSize(.large)
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch mode {
        case .reminder where FeatureFlags.escapeHatchEnabled:
            Button("Skip for now (counts as missed)") { model.skip() }
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.bottom, 32)
        case .manual:
            Button("Cancel") { onClose?() }
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.bottom, 32)
        default:
            EmptyView()
        }
    }

    // MARK: Flow

    private func checkPassed() {
        checker.snapshot(outcome: .passed) { sample in
            pendingSample = sample
            phase = .askFeedback
            // No answer in a few seconds: count the glass, with no feedback recorded.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: feedbackTimeout * 1_000_000_000)
                if phase == .askFeedback, pendingSample?.id == sample.id { finishDrink(feedback: .none) }
            }
        }
    }

    private func answer(correct: Bool) {
        if correct {
            finishDrink(feedback: .correct)
        } else {
            guard var sample = pendingSample else { return }
            sample.feedback = .wrong
            pendingSample = nil
            learnedNote = learner.record(sample)
            phase = .checking
            checker.apply(learner.profile)
            checker.reset()
        }
    }

    private func finishDrink(feedback: CheckSample.Feedback) {
        guard var sample = pendingSample else { return }
        pendingSample = nil
        sample.feedback = feedback
        learner.record(sample)
        model.drinkVerified(manual: mode == .manual)
        if mode == .manual {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onClose?() }
        }
    }

    /// The check missed a real drink. Learn from what it saw, then let the user try once more.
    /// (It doesn't log a glass by itself, so it can't be used to skip the check.)
    private func userSaysDrank() {
        checker.snapshot(outcome: .userSaysDrank) { sample in
            var sample = sample
            sample.feedback = .correct
            learnedNote = learner.record(sample)
            checker.apply(learner.profile)
            checker.reset()
        }
    }
}

/// The five drink-check steps, each turning green once it's seen.
private struct StepList: View {
    let passed: [Bool]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(DrinkCheck.Step.allCases) { step in
                let ok = passed.indices.contains(step.rawValue) && passed[step.rawValue]
                HStack(spacing: 10) {
                    Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ok ? .green : .white.opacity(0.7))
                        .font(.title3)
                    Text(step.title)
                        .font(.subheadline.weight(ok ? .semibold : .regular))
                }
                .animation(.easeInOut(duration: 0.2), value: ok)
            }
        }
        .padding(14)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
