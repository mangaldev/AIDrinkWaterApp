import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "drop.fill").font(.system(size: 72)).foregroundStyle(.blue)
            Text("DrinkWater").font(.largeTitle.bold())
            Text(onboardingText)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
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

    #if SCREEN_TIME
    private let onboardingText = "At the times you choose, DrinkWater blocks your other apps until the camera sees you take a drink. Everything is checked on your phone; no video is uploaded."
    private let buttonText = "Allow Screen Time & notifications"
    #else
    private let onboardingText = "At the times you choose, DrinkWater reminds you and stays locked until the camera sees you take a drink. Everything is checked on your phone; no video is uploaded."
    private let buttonText = "Allow notifications"
    #endif
}
