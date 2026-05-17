import SwiftUI

/// Lightweight slider-based weight editor, shared by "current weight" and "goal weight" actions
/// in the Profile screen.
struct EditWeightSheet: View {
    let title: String
    let initialKg: Double
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weightKg: Double

    init(title: String, initialKg: Double, onSave: @escaping (Double) -> Void) {
        self.title = title
        self.initialKg = initialKg
        self.onSave = onSave
        _weightKg = State(initialValue: initialKg)
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Text(title)
                    .font(Theme.Type.h2)
                    .foregroundStyle(Theme.Palette.text)
                    .padding(.top, Theme.Spacing.md)

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

                Spacer()

                VStack(spacing: Theme.Spacing.sm) {
                    PrimaryButton(title: "Save") {
                        onSave(weightKg)
                        dismiss()
                    }
                    SecondaryButton(title: "Cancel") { dismiss() }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
    }
}
