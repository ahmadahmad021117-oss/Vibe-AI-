import SwiftUI

enum RootDestination: Equatable {
    case splash
    case onboarding
    case planGeneration
    case planPreview(NutritionEngine.Result, NutritionEngine.Inputs, UnitsPref)
    case paywall
    case auth
    case main
}

struct RootCoordinator: View {
    @State private var destination: RootDestination = .splash
    @State private var auth = AuthService.shared
    @State private var entitlements = EntitlementService.shared
    @State private var onboardingState: OnboardingState?
    // Cal AI-style flow collects answers + computes the plan BEFORE sign-in, so
    // we stash the computed plan here and write it to Supabase once we have a
    // user (in `finalizeOnboarding`).
    @State private var pendingResult: NutritionEngine.Result?
    @State private var pendingInputs: NutritionEngine.Inputs?

    var body: some View {
        ZStack {
            switch destination {
            case .splash:
                SplashView()
                    .transition(.opacity)
                    .task { await bootstrap() }

            case .onboarding:
                OnboardingCoordinator { state in
                    onboardingState = state
                    withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                        destination = .planGeneration
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .planGeneration:
                PlanGenerationView(onboarding: onboardingState) { result, inputs, unitsPref in
                    pendingResult = result
                    pendingInputs = inputs
                    withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                        destination = .planPreview(result, inputs, unitsPref)
                    }
                }
                .transition(.opacity)

            case let .planPreview(result, inputs, unitsPref):
                PlanPreviewView(result: result, inputs: inputs, unitsPref: unitsPref) {
                    Task { await advanceFromPreview() }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .paywall:
                PaywallView(
                    onUnlocked: { Task { await advanceAfterPaywall() } },
                    onSkip: { Task { await advanceAfterPaywall() } }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .auth:
                // A new user who just finished onboarding has pending state to
                // commit, so default the form to "create account"; the sign-out
                // path (returning users) has none and defaults to sign-in.
                AuthGateView(
                    onAuthenticated: { Task { await afterSignIn() } },
                    startInSignUpMode: onboardingState != nil
                )
                .transition(.opacity)

            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Theme.Motion.base), value: destination)
        // React to sign-out anywhere in the app (Settings → "Sign out").
        // When the user goes from authenticated → not authenticated, snap back
        // to the sign-in screen so they can sign back in (their cloud data is intact).
        .onChange(of: auth.isAuthenticated) { _, isAuthed in
            if !isAuthed && destination != .splash {
                withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                    destination = .auth
                }
            }
        }
    }

    private func bootstrap() async {
        try? await Task.sleep(for: .milliseconds(900))
        await routeInitial()
    }

    /// Initial launch routing. Returning, fully set-up users go straight to the
    /// app; everyone else (new or signed-out) starts the Cal AI-style flow with
    /// the onboarding questions — sign-in comes at the very end.
    private func routeInitial() async {
        if auth.isAuthenticated {
            await PurchaseService.shared.loginIfNeeded()
            await entitlements.refresh()
            let profile = (try? await ProfileService.shared.fetchCurrent()) ?? nil
            if let profile, profile.onboardingCompletedAt != nil {
                // Reschedule only — never prompt at launch. The permission
                // request happens during onboarding / Settings, on a tap.
                await NotificationService.shared.rescheduleIfAuthorized(pref: profile.notificationPref)
                destination = .main
            } else {
                // Signed in but onboarding never finished — resume it. Writes
                // work immediately here since we already have a user.
                destination = .onboarding
            }
        } else {
            destination = .onboarding
        }
    }

    private func advanceFromPreview() async {
        await entitlements.refresh()
        // A returning, already-premium user re-running onboarding skips the
        // paywall; a new user is never premium yet, so they always see it.
        if entitlements.isPremium {
            await advanceAfterPaywall()
        } else {
            withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                destination = .paywall
            }
        }
    }

    /// After the paywall (whether they purchased or skipped). New users sign in
    /// now — the last step in the Cal AI flow. RevenueCat transfers any anonymous
    /// purchase onto their account when `loginIfNeeded` aliases the IDs.
    private func advanceAfterPaywall() async {
        if auth.isAuthenticated {
            await finalizeOnboarding()
            withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                destination = .main
            }
        } else {
            withAnimation(.easeInOut(duration: Theme.Motion.base)) {
                destination = .auth
            }
        }
    }

    private func afterSignIn() async {
        await PurchaseService.shared.loginIfNeeded()
        await entitlements.refresh()
        let profile = (try? await ProfileService.shared.fetchCurrent()) ?? nil
        if let profile, profile.onboardingCompletedAt != nil {
            // Returning user signing back in — data already lives in the cloud.
            await NotificationService.shared.rescheduleIfAuthorized(pref: profile.notificationPref)
        } else {
            // Brand-new user: persist everything collected before sign-in.
            await finalizeOnboarding()
        }
        withAnimation(.easeInOut(duration: Theme.Motion.base)) {
            destination = .main
        }
    }

    /// Single post-sign-in write of all onboarding data. Pre-auth, every service
    /// call here is a no-op (they guard on `userId`), so this is where the
    /// profile, goal, targets, and completion flag actually land in Supabase.
    private func finalizeOnboarding() async {
        guard let state = onboardingState else { return }
        await state.commit()
        if let result = pendingResult, let inputs = pendingInputs {
            try? await TargetService.shared.writeLatest(result, inputs: inputs)
        }
        try? await ProfileService.shared.markOnboardingComplete()
        await NotificationService.shared.rescheduleIfAuthorized(pref: state.notificationPref)
        OnboardingState.clear()
    }
}
