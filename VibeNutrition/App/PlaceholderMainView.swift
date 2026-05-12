import SwiftUI

/// Stand-in until Phase 4 dashboard lands.
struct PlaceholderMainView: View {
    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Gradients.accent)
                Text("Onboarding complete")
                    .font(Theme.Type.h2)
                    .foregroundStyle(Theme.Palette.text)
                Text("Plan generation lands in Phase 2.")
                    .font(Theme.Type.body)
                    .foregroundStyle(Theme.Palette.textMuted)
                SecondaryButton(title: "Sign out") {
                    Task { try? await AuthService.shared.signOut() }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
            }
        }
    }
}
