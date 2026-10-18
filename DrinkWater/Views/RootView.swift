import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if !model.isAuthorized {
                OnboardingView()
            } else {
                HomeView()
            }
        }
        // While locked, the drink check covers the whole app and can't be swiped away.
        .fullScreenCover(isPresented: Binding(get: { model.isLocked }, set: { _ in })) {
            DrinkCheckView()
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
