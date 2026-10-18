import Foundation

enum FeatureFlags {
    /// Shows a "Skip for now" button on the drink check screen.
    /// Keep this on for App Store builds: App Review must be able to get past the camera check.
    static let escapeHatchEnabled = true

    /// "Lock now" and the detection details overlay. Only in Debug builds (running from Xcode);
    /// App Store builds use the Release configuration, where these are hidden.
    #if DEBUG
    static let testingTools = true
    #else
    static let testingTools = false
    #endif
}
