import SwiftUI

/// Bottom tab container. Two tabs: Home (today's intake + actions) and Progress (plan + trajectory).
/// Profile/Settings is reachable from a profile icon in each tab's header — not a tab of its own.
struct MainTabView: View {
    /// Shared model so saving pace or weight in Progress reflects on Home (ring, targets) instantly.
    @State private var vm = DashboardViewModel()
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, progress }

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

            ProgressTabView(vm: vm)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.progress)
        }
        .tint(Theme.Palette.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
}
