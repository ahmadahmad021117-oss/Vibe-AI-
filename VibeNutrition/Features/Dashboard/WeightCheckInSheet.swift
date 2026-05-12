import SwiftUI

struct WeightCheckInSheet: View {
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var weightKg: Double = 70
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Text("Weight check-in")
                    .font(Theme.Type.h2)
                    .foregroundStyle(Theme.Palette.text)
                    .padding(.top, Theme.Spacing.md)

                Text("Aim for once a week, same time of day.")
                    .font(Theme.Type.body)
                    .foregroundStyle(Theme.Palette.textMuted)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", weightKg))
                        .font(Theme.Type.numeralXL)
                        .foregroundStyle(Theme.Palette.text)
                    Text("kg")
                        .font(Theme.Type.h3)
                        .foregroundStyle(Theme.Palette.textMuted)
                }

                Slider(value: $weightKg, in: 35...200, step: 0.1)
                    .tint(Theme.Palette.accent)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .onChange(of: weightKg) { _, _ in Haptics.select() }

                if let error {
                    Text(error)
                        .font(Theme.Type.caption)
                        .foregroundStyle(Theme.Palette.danger)
                }

                Spacer()

                VStack(spacing: Theme.Spacing.sm) {
                    PrimaryButton(title: saving ? "Saving…" : "Log weight", isEnabled: !saving) {
                        Task { await save() }
                    }
                    SecondaryButton(title: "Cancel") { onDismiss() }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .task {
            if let last = try? await WeightLogService.shared.fetchLatest() {
                weightKg = last.weightKg
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await WeightLogService.shared.write(weightKg: weightKg)
            Haptics.success()
            onDismiss()
        } catch {
            Haptics.error()
            self.error = error.localizedDescription
        }
    }
}
