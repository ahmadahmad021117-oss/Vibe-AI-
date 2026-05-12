import SwiftUI

enum RootDestination {
    case splash
    case auth
    case onboarding
    case main
}

struct RootCoordinator: View {
    @State private var destination: RootDestination = .splash
    @State private var auth = AuthService.shared

    var body: some View {
        ZStack {
            switch destination {
            case .splash:
                SplashView()
                    .transition(.opacity)
                    .task { await bootstrap() }
            case .auth:
                AuthGateView(onAuthenticated: { Task { await routeAfterAuth() } })
                    .transition(.opacity)
            case .onboarding:
                OnboardingCoordinator {
                    withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                        destination = .main
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .main:
                PlaceholderMainView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Theme.Motion.base), value: destination)
    }

    private func bootstrap() async {
        // Splash min duration — punchy but not interruptive.
        try? await Task.sleep(for: .milliseconds(900))
        await routeAfterAuth()
    }

    private func routeAfterAuth() async {
        if !auth.isAuthenticated {
            destination = .auth
            return
        }
        do {
            let profile = try await ProfileService.shared.fetchCurrent()
            destination = (profile?.onboardingCompletedAt != nil) ? .main : .onboarding
        } catch {
            destination = .onboarding
        }
    }
}
