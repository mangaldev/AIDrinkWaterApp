import SwiftUI

/// Full-screen camera check.
/// - `.reminder`: shown while a reminder is due; can only be left by drinking (or Skip, if enabled).
/// - `.manual`: opened from "Add a glass"; has a Cancel button.
struct DrinkCheckView: View {
    enum Mode { case reminder, manual }

    let mode: Mode
    var onClose: (() -> Void)? = nil

    @EnvironmentObject var model: AppModel
    @StateObject private var camera = CameraSession()
    @StateObject private var checker = DrinkCheck()
    @AppStorage("showDetectionDebug") private var showDebug = false

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()

            VStack(spacing: 16) {
                Text(mode == .reminder ? "Time to drink water" : "Add a glass")
                    .font(.title.bold())
                    .padding(.top, 40)
                Text(checker.hint)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if showDebug && FeatureFlags.testingTools {
                    Text(checker.debugText)
                        .font(.caption.monospaced())
                        .padding(8)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                ProgressView(value: checker.progress)
                    .tint(.blue)
                    .scaleEffect(x: 1, y: 3)
                    .padding(.horizontal, 40)

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
            .foregroundStyle(.white)
            .shadow(radius: 4)
        }
        .background(Color.black)
        .onTapGesture(count: 3) {   // triple-tap shows what the detector sees (Debug builds only)
            if FeatureFlags.testingTools { showDebug.toggle() }
        }
        .onAppear {
            checker.onVerified = {
                model.drinkVerified(manual: mode == .manual)
                if mode == .manual {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onClose?() }
                }
            }
            camera.onFrame = { [weak checker] buffer in checker?.process(buffer) }
            // Alert before the camera starts: iOS can mute vibration while capture is running.
            if mode == .reminder { AlertPlayer.playReminderAlert() }
            camera.start()
        }
        .onDisappear { camera.stop() }
    }
}
