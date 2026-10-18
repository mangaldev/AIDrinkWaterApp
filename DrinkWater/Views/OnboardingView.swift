import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
        VStack(spacing: 24) {
            Spacer(minLength: 24)
            Image(systemName: "drop.fill").font(.system(size: 72)).foregroundStyle(.blue)
            Text("WaterSipAI").font(.largeTitle.bold())
            Text(onboardingText)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            PrivacyPointsView()
                .padding(.top, 8)
            Spacer()
            Button {
                Task { await model.requestPermissions() }
            } label: {
                Text(buttonText).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        }
    }

    #if SCREEN_TIME
    private let onboardingText = "At the times you choose, WaterSipAI blocks your other apps until the camera sees you take a drink."
    private let buttonText = "Allow Screen Time & notifications"
    #else
    private let onboardingText = "At the times you choose, WaterSipAI reminds you and stays locked until the camera sees you take a drink."
    private let buttonText = "Allow notifications"
    #endif
}
