import SwiftUI

/// Full-screen camera check shown while locked.
struct DrinkCheckView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var camera = CameraSession()
    @StateObject private var checker = DrinkCheck()

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Drink some water")
                    .font(.title.bold())
                    .padding(.top, 40)
                Text(checker.hint)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                ProgressView(value: checker.progress)
                    .tint(.blue)
                    .scaleEffect(x: 1, y: 3)
                    .padding(.horizontal, 40)

                if FeatureFlags.escapeHatchEnabled {
                    Button("Skip for now") { model.skip() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .padding(.bottom, 32)
                }
            }
            .foregroundStyle(.white)
            .shadow(radius: 4)
        }
        .background(Color.black)
        .onAppear {
            checker.onVerified = { model.drinkVerified() }
            camera.onFrame = { [weak checker] buffer in checker?.process(buffer) }
            camera.start()
        }
        .onDisappear { camera.stop() }
    }
}
