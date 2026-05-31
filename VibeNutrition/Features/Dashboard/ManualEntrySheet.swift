import SwiftUI

struct ManualEntrySheet: View {
    let onSaved: () -> Void
    /// Called when a non-premium user taps "Estimate with AI". The presenter
    /// (DashboardView) dismisses this sheet and shows the paywall.
    var onRequestPaywall: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    // AI text-estimate section
    @State private var description = ""
    @State private var estimating = false
    @State private var aiItems: [FoodItem] = []
    @State private var aiError: String?
    @State private var savingAI = false

    // Manual single-item section
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
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    aiSection

                    dividerRow

                    manualSection

                    SecondaryButton(title: "Cancel") { dismiss() }
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }

    // MARK: - AI section

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add a meal")
                    .font(Theme.Typo.h2)
                    .foregroundStyle(Theme.Palette.text)
                Text("Describe it, we'll do the math.")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }

            TextField(
                "",
                text: $description,
                prompt: Text("e.g. 4 eggs and a toast").foregroundStyle(Theme.Palette.textDim),
                axis: .vertical
            )
            .lineLimit(2...4)
            .padding()
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.md))
            .foregroundStyle(Theme.Palette.text)

            if let aiError {
                Text(aiError)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.danger)
            }

            if aiItems.isEmpty {
                PrimaryButton(title: estimating ? "Estimating…" : "Estimate with AI",
                              isEnabled: !estimating && canEstimate) {
                    Task { await estimate() }
                }
            } else {
                aiResults
            }
        }
    }

    private var aiResults: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(Array(aiItems.enumerated()), id: \.offset) { index, item in
                aiItemCard(item) { aiItems.remove(at: index) }
            }

            let t = aiTotals
            HStack {
                Text("Total")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Spacer()
                Text("\(t.kcal) kcal · P \(Int(t.protein.rounded()))g · C \(Int(t.carbs.rounded()))g · F \(Int(t.fat.rounded()))g")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.text)
            }
            .padding(.top, 2)

            PrimaryButton(title: savingAI ? "Saving…" : "Save \(aiItems.count) item\(aiItems.count == 1 ? "" : "s")",
                          isEnabled: !savingAI && !aiItems.isEmpty) {
                Task { await saveAI() }
            }
            SecondaryButton(title: "Start over") {
                aiItems = []
                aiError = nil
            }
        }
    }

    private func aiItemCard(_ item: FoodItem, onRemove: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name.capitalized)
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Text("\(Int(item.grams.rounded()))g")
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.accent)
                Button {
                    Haptics.tapMedium()
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.textDim)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: Theme.Spacing.md) {
                Text("\(item.kcal) kcal")
                Spacer()
                Text("P \(Int(item.proteinG.rounded()))g")
                Text("C \(Int(item.carbsG.rounded()))g")
                Text("F \(Int(item.fatG.rounded()))g")
            }
            .font(Theme.Typo.caption)
            .foregroundStyle(Theme.Palette.textMuted)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private var dividerRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Rectangle().fill(Theme.Palette.surface).frame(height: 1)
            Text("or enter it manually")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textDim)
                .fixedSize()
            Rectangle().fill(Theme.Palette.surface).frame(height: 1)
        }
    }

    // MARK: - Manual section

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
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

    // MARK: - AI logic

    private var canEstimate: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var aiTotals: (kcal: Int, protein: Double, carbs: Double, fat: Double) {
        aiItems.reduce((0, 0.0, 0.0, 0.0)) { acc, item in
            (acc.0 + item.kcal, acc.1 + item.proteinG, acc.2 + item.carbsG, acc.3 + item.fatG)
        }
    }

    private func estimate() async {
        // Premium gate: bounce non-premium users to the paywall instead of
        // surfacing an error. The server-side gate is still authoritative.
        guard EntitlementService.shared.isPremium else {
            dismiss()
            onRequestPaywall()
            return
        }
        aiError = nil
        estimating = true
        defer { estimating = false }
        do {
            let food = try await FoodScanService.shared.analyzeText(
                description: description.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            aiItems = food.items
            Haptics.success()
        } catch FoodScanError.premiumRequired {
            dismiss()
            onRequestPaywall()
        } catch {
            Haptics.error()
            aiError = error.friendlyMessage
        }
    }

    private func saveAI() async {
        savingAI = true
        defer { savingAI = false }
        do {
            try await FoodLogService.shared.write(items: aiItems, imagePath: nil, source: .manual)
            Haptics.success()
            onSaved()
        } catch {
            Haptics.error()
            aiError = error.friendlyMessage
        }
    }

    // MARK: - Manual logic

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
