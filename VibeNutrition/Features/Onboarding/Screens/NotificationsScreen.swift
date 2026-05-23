import SwiftUI

#Preview {
    NotificationsScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

struct NotificationsScreen: View {
    @Bindable var state: OnboardingState

    private let style: [NotificationPref: (String, Color)] = [
        .full:      ("bell.badge.fill", .red),
        .important: ("bell.fill",       .orange),
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
                Task { await state.finish() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: Theme.Spacing.sm) {
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
