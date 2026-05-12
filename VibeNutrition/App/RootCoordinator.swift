import SwiftUI

enum RootDestination: Equatable {
    case splash
    case auth
    case onboarding
    case planGeneration
    case planPreview(NutritionEngine.Result, NutritionEngine.Inputs)
    case main
}

struct RootCoordinator: View {
    @State private var destination: RootDestination = .splash
    @State private var auth = AuthService.shared
    @State private var onboardingState: OnboardingState?

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
                OnboardingCoordinator { state in
                    onboardingState = state
                    withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                        destination = .planGeneration
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .planGeneration:
                PlanGenerationView(onboarding: onboardingState) { result, inputs in
                    withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                        destination = .planPreview(result, inputs)
                    }
                }
                .transition(.opacity)

            case let .planPreview(result, inputs):
                PlanPreviewView(result: result, inputs: inputs) {
                    withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                        // Paywall will slot in here once Phase 5 lands.
                        destination = .main
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .main:
                DashboardView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Theme.Motion.base), value: destination)
    }

    private func bootstrap() async {
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
            if profile?.onboardingCompletedAt != nil {
                // Returning user: skip straight to main (we'll fetch their last target there in Phase 4).
                destination = .main
            } else {
                destination = .onboarding
            }
        } catch {
            destination = .onboarding
        }
    }
}
