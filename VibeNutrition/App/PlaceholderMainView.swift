import SwiftUI

/// Stand-in until Phase 4 dashboard lands. For Phase 3 it exposes the scan flow.
struct PlaceholderMainView: View {
    @State private var showingScan = false
    @State private var lastScanWritten = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: lastScanWritten ? "checkmark.seal.fill" : "fork.knife.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Gradients.accent)
                Text(lastScanWritten ? "Logged to today" : "Ready to scan")
                    .font(Theme.Type.h2)
                    .foregroundStyle(Theme.Palette.text)
                Text("Dashboard arrives in Phase 4.")
                    .font(Theme.Type.body)
                    .foregroundStyle(Theme.Palette.textMuted)

                PrimaryButton(title: "Scan a meal") { showingScan = true }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)

                SecondaryButton(title: "Sign out") {
                    Task { try? await AuthService.shared.signOut() }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
        .fullScreenCover(isPresented: $showingScan) {
            ScanFlowView { written in
                lastScanWritten = written
                showingScan = false
            }
        }
        .task { await EntitlementService.shared.refresh() }
    }
}
