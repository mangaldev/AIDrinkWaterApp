import Foundation

/// Public pages linked from the app and the App Store listing.
/// They're served by GitHub Pages from the repo's docs/ folder (see docs/README.md).
enum AppLinks {
    static let privacy = URL(string: "https://mangaldev.github.io/AIDrinkWaterApp/privacy.html")!
    static let support = URL(string: "https://mangaldev.github.io/AIDrinkWaterApp/support.html")!
}
