import SwiftUI

/// The app's privacy promise, shown on onboarding and in Settings. Keep this in sync with
/// docs/privacy.html and appstore/listing.md.
enum PrivacyPromise {
    struct Point: Identifiable {
        let icon: String
        let title: String
        let detail: String
        var id: String { title }
    }

    static let points = [
        Point(icon: "cpu", title: "On-device AI",
              detail: "The drink check runs on Apple's local AI models, right on your iPhone."),
        Point(icon: "wifi.slash", title: "Works offline",
              detail: "No internet needed. The app never talks to a server."),
        Point(icon: "video.slash", title: "Nothing is recorded",
              detail: "No photos or video are ever saved, uploaded or sent anywhere."),
        Point(icon: "lock.shield", title: "No data leaves your phone",
              detail: "No account, no ads, no tracking. Your history stays on this iPhone."),
    ]

    /// Short line for the camera screen.
    static let badge = "On-device AI · Offline · Nothing recorded"
}

struct PrivacyPointsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(PrivacyPromise.points) { p in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: p.icon)
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.title).font(.subheadline.bold())
                        Text(p.detail).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Small pill shown on the camera screen.
struct PrivacyBadge: View {
    var body: some View {
        Label(PrivacyPromise.badge, systemImage: "lock.fill")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.45), in: Capsule())
    }
}
