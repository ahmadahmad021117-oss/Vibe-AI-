import SwiftUI

struct NumberStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var suffix: String = ""

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            stepperButton(systemImage: "minus") { adjust(-1) }
                .disabled(value <= range.lowerBound)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(Theme.Typography.numeralXL)
                    .foregroundStyle(Theme.Palette.text)
                    .contentTransition(.numericText(value: Double(value)))
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(Theme.Typography.h3)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
            }
            .frame(minWidth: 140)

            stepperButton(systemImage: "plus") { adjust(1) }
                .disabled(value >= range.upperBound)
        }
        .frame(maxWidth: .infinity)
    }

    private func adjust(_ delta: Int) {
        let next = (value + delta).clamped(to: range)
        if next != value {
            Haptics.select()
            value = next
        }
    }

    private func stepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
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

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
