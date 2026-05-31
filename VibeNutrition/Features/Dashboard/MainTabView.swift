import SwiftUI

/// Bottom tab container. Three tabs: Home, Scan (center), Progress.
/// Scan is a "trigger" tab — selecting it does not navigate, it presents the camera
/// flow over the current tab and restores the previously-selected tab when closed.
/// Profile/Settings is reachable from a profile icon in each tab's header.
struct MainTabView: View {
    /// Shared model so saving pace or weight in Progress reflects on Home (ring, targets) instantly.
    @State private var vm = DashboardViewModel()
    @State private var entitlements = EntitlementService.shared
    @State private var selection: Tab = .home
    /// Remembers the last "real" tab so the Scan trigger can restore it after dismissal.
    @State private var lastTab: Tab = .home
    @State private var showingScan = false
    @State private var showingPaywall = false

    enum Tab: Hashable { case home, scan, progress }

    init() {
        // Match the dark theme on the tab bar background.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.Palette.bgElevated)
        appearance.shadowColor = UIColor(Theme.Palette.border)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(vm: vm)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            // Placeholder for the center Scan tab. The view never actually renders
            // because `.onChange(of: selection)` intercepts the tap and presents
            // the scan flow modally instead. We keep a `Color.clear` here so the
            // tab bar reserves space for the camera button between Home and Progress.
            Color.clear
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }
                .tag(Tab.scan)

            ProgressTabView(vm: vm)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.progress)
        }
        .tint(Theme.Palette.accent)
        .onChange(of: selection) { _, new in
            if new == .scan {
                Haptics.tapMedium()
                // Non-premium users get the paywall here; the camera never
                // opens for them. Mirrors the gate on the Home actions row
                // so both entry points behave identically.
                if entitlements.isPremium {
                    showingScan = true
                } else {
                    showingPaywall = true
                }
                // Restore the previously-active tab so we don't get stuck on an
                // empty Scan view if the user dismisses the camera or paywall.
                selection = lastTab
            } else {
                lastTab = new
            }
        }
        .fullScreenCover(isPresented: $showingScan) {
            ScanFlowView { _ in
                showingScan = false
                Task { await vm.load() }
            }
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView(
                onUnlocked: {
                    showingPaywall = false
                    showingScan = true
                },
                onSkip: { showingPaywall = false }
            )
        }
    }
}

#Preview {
    MainTabView()
}
