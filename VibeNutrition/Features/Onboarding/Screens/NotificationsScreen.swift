import SwiftUI

struct NotificationsScreen: View {
    @Bindable var state: OnboardingState

    private let icons: [NotificationPref: String] = [
        .full: "bell.badge.fill",
        .important: "bell.fill",
        .off: "bell.slash.fill",
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
                Task { await state.finish() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(NotificationPref.allCases) { pref in
                    OptionCard(
                        title: pref.label,
                        subtitle: subtitles[pref],
                        systemImage: icons[pref],
                        isSelected: state.notificationPref == pref
                    ) {
                        state.notificationPref = pref
                    }
                }
            }
        }
    }
}
