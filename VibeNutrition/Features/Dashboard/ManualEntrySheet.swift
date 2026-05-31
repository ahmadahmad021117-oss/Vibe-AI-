import SwiftUI

struct ManualEntrySheet: View {
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var grams = "150"
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Add a meal manually")
                        .font(Theme.Typo.h2)
                        .foregroundStyle(Theme.Palette.text)

                    field("Name", value: $name, placeholder: "e.g. Chicken & rice")
                    field("Grams", value: $grams, placeholder: "150", keyboard: .decimalPad)
                    field("kcal", value: $kcal, placeholder: kcalPlaceholder, keyboard: .numberPad)
                    HStack(spacing: Theme.Spacing.sm) {
                        field("Protein g", value: $protein, placeholder: "0", keyboard: .decimalPad)
                        field("Carbs g", value: $carbs, placeholder: "0", keyboard: .decimalPad)
                        field("Fat g", value: $fat, placeholder: "0", keyboard: .decimalPad)
                    }

                    if let error {
                        Text(error)
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.danger)
                    }

                    PrimaryButton(title: saving ? "Saving…" : "Save", isEnabled: !saving && canSave) {
                        Task { await save() }
                    }

                    SecondaryButton(title: "Cancel") { dismiss() }
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }

    private func field(_ label: String, value: Binding<String>,
                       placeholder: String = "",
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
            TextField("", text: value, prompt: Text(placeholder).foregroundStyle(Theme.Palette.textDim))
                .keyboardType(keyboard)
                .padding()
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.md))
                .foregroundStyle(Theme.Palette.text)
        }
    }

    /// Live-computed kcal from the macros, shown as the kcal field's
    /// placeholder. Lets the user fill macros only and skip kcal — Save uses
    /// the computed value when the field is left blank.
    private var computedKcal: Int? {
        let p = Double(protein) ?? 0
        let c = Double(carbs) ?? 0
        let f = Double(fat) ?? 0
        let total = p * 4 + c * 4 + f * 9
        return total > 0 ? Int(total.rounded()) : nil
    }

    private var kcalPlaceholder: String {
        if let k = computedKcal { return "\(k) (from macros)" }
        return "0"
    }

    private var effectiveKcal: Int? {
        if let typed = Int(kcal) { return typed }
        return computedKcal
    }

    private var canSave: Bool {
        !name.isEmpty && Double(grams) != nil && effectiveKcal != nil
    }

    private func save() async {
        saving = true
        defer { saving = false }
        guard
            let gramsD = Double(grams),
            let kcalI = effectiveKcal
        else {
            error = "Grams and kcal are required."
            return
        }
        let item = FoodItem(
            name: name,
            grams: gramsD,
            kcal: kcalI,
            proteinG: Double(protein) ?? 0,
            carbsG: Double(carbs) ?? 0,
            fatG: Double(fat) ?? 0,
            confidence: nil
        )
        do {
            try await FoodLogService.shared.write(items: [item], imagePath: nil, source: .manual)
            Haptics.success()
            onSaved()
        } catch {
            Haptics.error()
            self.error = error.friendlyMessage
        }
    }
}

#Preview {
    ManualEntrySheet(onSaved: {})
        .preferredColorScheme(.dark)
}
