import Foundation
import Observation

/// Carries an intent fired from outside the app (currently the home/lock-screen
/// widgets) into the running UI. `MainTabView` observes `pendingScan` and opens
/// the camera flow when it flips true, applying the same premium gate as the
/// in-app Scan tab.
@MainActor
@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()
    private init() {}

    /// Set when a `vibecal://scan` link arrives. `MainTabView` consumes it.
    var pendingScan = false

    func handle(_ url: URL) {
        guard url.scheme == WidgetDeepLink.scheme else { return }
        if url.host == "scan" {
            pendingScan = true
        }
    }
}
