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
                        .font(Theme.Typography.h2)
                        .foregroundStyle(Theme.Palette.text)

                    field("Name", value: $name)
                    field("Grams", value: $grams, keyboard: .decimalPad)
                    field("kcal", value: $kcal, keyboard: .numberPad)
                    HStack(spacing: Theme.Spacing.sm) {
                        field("Protein g", value: $protein, keyboard: .decimalPad)
                        field("Carbs g", value: $carbs, keyboard: .decimalPad)
                        field("Fat g", value: $fat, keyboard: .decimalPad)
                    }

                    if let error {
                        Text(error)
                            .font(Theme.Typography.caption)
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
        .preferredColorScheme(.dark)
    }

    private func field(_ label: String, value: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textMuted)
            TextField("", text: value)
                .keyboardType(keyboard)
                .padding()
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.md))
                .foregroundStyle(Theme.Palette.text)
        }
    }

    private var canSave: Bool {
        !name.isEmpty && Double(grams) != nil && Int(kcal) != nil
    }

    private func save() async {
        saving = true
        defer { saving = false }
        guard
            let gramsD = Double(grams),
            let kcalI = Int(kcal)
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
            self.error = error.localizedDescription
        }
    }
}
