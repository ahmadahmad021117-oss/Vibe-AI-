import SwiftUI

/// Last onboarding step. The iOS system permission dialog is gated on the
/// user's choice: only users who actually want notifications see it, and
/// it fires on Continue (not screen-appear) so the prompt arrives with
/// fresh context.
struct NotificationsScreen: View {
    @Bindable var state: OnboardingState

    private let style: [NotificationPref: (String, Color)] = [
        .full:      ("bell.badge.fill", .red),
        .important: ("bell.fill", .orange),
        .off:       ("bell.slash.fill", .gray),
    ]

    private let subtitles: [NotificationPref: String] = [
        .full: "Daily reminders + weekly progress",
        .important: "Just the stuff that matters",
        .off: "We'll stay quiet",
    ]

    var body: some View {
        OnboardingCard(
            title: "How should we reach out?",
            subtitle: nil,
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task {
                    // Only fire the iOS permission dialog if the user
                    // actually wants notifications. `apply(pref:)` requests
                    // authorization and schedules in one shot; for `.off`
                    // we skip it entirely so no system prompt appears.
                    if state.notificationPref != .off {
                        await NotificationService.shared.apply(pref: state.notificationPref)
                    }
                    // finish() is the LAST thing we do: it commits, marks
                    // the profile complete, and clears persisted onboarding
                    // state. Setting step = .done directly (instead of
                    // calling advance()) avoids re-persisting step = .done
                    // back into UserDefaults — if a future user signed in
                    // on the same install, restore() would otherwise load
                    // step = .done and the OnboardingCoordinator would
                    // render EmptyView with no `onChange` trigger to
                    // escape, producing a black screen.
                    await state.finish()
                    withAnimation(Theme.Motion.spring) {
                        state.step = .done
                    }
                }
            }
        ) {
            VStack(spacing: Onboarding.rowGap) {
                ForEach(NotificationPref.allCases) { pref in
                    let s = style[pref]
                    OptionCard(
                        title: pref.label,
                        subtitle: subtitles[pref],
                        systemImage: s?.0,
                        tint: s?.1,
                        isSelected: state.notificationPref == pref
                    ) {
                        state.notificationPref = pref
                    }
                }
            }
        }
    }
}

#Preview {
    NotificationsScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}
