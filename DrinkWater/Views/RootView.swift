import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if !model.isAuthorized {
                OnboardingView()
            } else {
                TabView {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "drop.fill") }
                    StatsView()
                        .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            }
        }
        // While a reminder is due, the drink check covers the whole app and can't be swiped away.
        .fullScreenCover(isPresented: Binding(get: { model.isLocked }, set: { _ in })) {
            DrinkCheckView(mode: .reminder)
                .environmentObject(model)
                .interactiveDismissDisabled(true)
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
