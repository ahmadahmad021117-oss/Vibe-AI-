import SwiftUI

/// Lightweight editor for the daily water goal. Steps in 250 ml increments
/// (one glass) between 500 ml and 5 L.
struct WaterGoalSheet: View {
    let initialMl: Int
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var goalMl: Int

    private let step = 250
    private let range = 500...5000

    init(initialMl: Int, onSave: @escaping (Int) -> Void) {
        self.initialMl = initialMl
        self.onSave = onSave
        _goalMl = State(initialValue: initialMl)
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Text("Daily water goal")
                    .font(Theme.Typo.h2)
                    .foregroundStyle(Theme.Palette.text)
                    .padding(.top, Theme.Spacing.md)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", Double(goalMl) / 1000))
                        .font(Theme.Typo.numeralXL)
                        .foregroundStyle(Theme.Palette.text)
                    Text("L")
                        .font(Theme.Typo.h3)
                        .foregroundStyle(Theme.Palette.textMuted)
                }

                HStack(spacing: Theme.Spacing.lg) {
                    stepButton(systemImage: "minus") { adjust(-step) }
                        .disabled(goalMl <= range.lowerBound)
                    Text("\(goalMl.grouped) ml")
                        .font(Theme.Typo.h3)
                        .foregroundStyle(Theme.Palette.textMuted)
                        .frame(minWidth: 120)
                    stepButton(systemImage: "plus") { adjust(step) }
                        .disabled(goalMl >= range.upperBound)
                }

                Spacer()

                VStack(spacing: Theme.Spacing.sm) {
                    PrimaryButton(title: "Save") {
                        onSave(goalMl)
                        dismiss()
                    }
                    SecondaryButton(title: "Cancel") { dismiss() }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }

    private func adjust(_ delta: Int) {
        let next = min(max(goalMl + delta, range.lowerBound), range.upperBound)
        if next != goalMl {
            Haptics.select()
            goalMl = next
        }
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Palette.text)
                .frame(width: 56, height: 56)
                .background(Theme.Palette.surface, in: Circle())
                .overlay(Circle().stroke(Theme.Palette.border, lineWidth: 1))
        }
    }
}
