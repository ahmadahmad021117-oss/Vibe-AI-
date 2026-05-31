import SwiftUI

/// Detail sheet for a single meal idea. Opened by tapping a card in the
/// home-screen "Meal ideas" row, or a row in the saved-meals registry.
///
/// The two entry points share the same body but differ in their actions:
/// a fresh suggestion can be *saved* to the registry, a registry meal can be
/// *removed*. Both can be logged straight to today.
struct MealIdeaDetailView: View {
    enum Context: Equatable {
        case suggestion          // came from the AI meal-ideas row
        case saved(id: UUID)     // came from the saved-meals registry
    }

    let name: String
    let description: String
    let kcal: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    /// Recipe for ONE serving. Quantities and macros scale by `servings`.
    var ingredients: [MealIngredient] = []
    var steps: [String] = []
    let context: Context
    /// Called after a successful log or registry change so callers can refresh.
    var onChange: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var isSaved = false
    @State private var working = false
    @State private var error: String?
    /// Portion multiplier. The card's macros + ingredient amounts are all the
    /// single-serving baseline; this scales everything the user sees and logs.
    @State private var servings: Double = 1

    // Scaled values for the current portion. The base figures always describe
    // one serving, so logging/saving derives from these.
    private var scaledKcal: Int { Int((Double(kcal) * servings).rounded()) }
    private var scaledProtein: Double { proteinG * servings }
    private var scaledCarbs: Double { carbsG * servings }
    private var scaledFat: Double { fatG * servings }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    headerBlock
                    if !description.isEmpty { descriptionBlock }
                    portionBlock
                    macrosBlock
                    if !ingredients.isEmpty { ingredientsBlock }
                    if !steps.isEmpty { stepsBlock }
                    if let error {
                        Text(error)
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.danger)
                    }
                    actions
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .task {
            if case .suggestion = context {
                isSaved = await SavedMealService.shared.isSaved(name: name)
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(name)
                .font(Theme.Typo.h2)
                .foregroundStyle(Theme.Palette.text)
            Text("\(scaledKcal) kcal")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.accent)
        }
    }

    private var descriptionBlock: some View {
        Text(description)
            .font(Theme.Typo.body)
            .foregroundStyle(Theme.Palette.textMuted)
    }

    private var portionBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Servings")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.textMuted)
                Spacer()
                Text(servingsLabel)
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
            }
            HStack(spacing: Theme.Spacing.md) {
                stepperButton(systemName: "minus") {
                    servings = max(0.5, servings - 0.5)
                }
                .disabled(servings <= 0.5)
                Slider(value: $servings, in: 0.5...6, step: 0.5)
                    .tint(Theme.Palette.accent)
                stepperButton(systemName: "plus") {
                    servings = min(6, servings + 0.5)
                }
                .disabled(servings >= 6)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private var servingsLabel: String {
        // Drop the decimal for whole numbers (2 not 2.0), keep it otherwise (1.5).
        servings.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(servings))
            : String(format: "%.1f", servings)
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tapLight()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.Palette.surfaceHi)
                    .frame(width: 36, height: 36)
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Palette.text)
            }
        }
    }

    private var macrosBlock: some View {
        VStack(spacing: Theme.Spacing.sm) {
            macroRow("Protein", grams: scaledProtein)
            macroRow("Carbs", grams: scaledCarbs)
            macroRow("Fat", grams: scaledFat)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func macroRow(_ label: String, grams: Double) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
            Spacer()
            Text("\(Int(grams.rounded())) g")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
        }
    }

    private var ingredientsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Ingredients")
                .font(Theme.Typo.h3)
                .foregroundStyle(Theme.Palette.text)
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(ingredients.enumerated()), id: \.offset) { _, ing in
                    HStack(alignment: .firstTextBaseline) {
                        Text(ing.name)
                            .font(Theme.Typo.body)
                            .foregroundStyle(Theme.Palette.text)
                        Spacer(minLength: Theme.Spacing.sm)
                        Text(amountLabel(ing))
                            .font(Theme.Typo.bodyBold)
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
    }

    private func amountLabel(_ ing: MealIngredient) -> String {
        let scaled = ing.quantity * servings
        // Whole quantities read cleaner without a trailing .0 (200 g not 200.0 g).
        let qty = scaled.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(scaled))
            : String(format: "%.1f", scaled)
        return "\(qty) \(ing.unit)"
    }

    private var stepsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Steps")
                .font(Theme.Typo.h3)
                .foregroundStyle(Theme.Palette.text)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Text("\(idx + 1)")
                            .font(Theme.Typo.bodyBold)
                            .foregroundStyle(Theme.Palette.accent)
                            .frame(width: 20, alignment: .leading)
                        Text(step)
                            .font(Theme.Typo.body)
                            .foregroundStyle(Theme.Palette.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch context {
        case .suggestion:
            PrimaryButton(
                title: isSaved ? "Saved to registry" : "Save to meal registry",
                isEnabled: !isSaved && !working
            ) {
                Task { await saveToRegistry() }
            }
            SecondaryButton(title: "Log to today") {
                Task { await logToToday() }
            }
        case .saved:
            PrimaryButton(title: "Log to today", isEnabled: !working) {
                Task { await logToToday() }
            }
            removeButton
        }
        SecondaryButton(title: "Close") { dismiss() }
    }

    private var removeButton: some View {
        Button {
            Haptics.tapLight()
            Task { await remove() }
        } label: {
            Text("Remove from registry")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .disabled(working)
        .accessibilityLabel("Remove from meal registry")
    }

    private func logToToday() async {
        working = true
        defer { working = false }
        // Log the scaled portion the user actually chose, not the 1-serving base.
        let loggedName = servings == 1 ? name : "\(name) (\(servingsLabel)×)"
        let item = FoodItem(
            name: loggedName, grams: 0, kcal: scaledKcal,
            proteinG: scaledProtein, carbsG: scaledCarbs, fatG: scaledFat, confidence: nil
        )
        do {
            try await FoodLogService.shared.write(items: [item], imagePath: nil, source: .manual)
            Haptics.success()
            onChange()
            dismiss()
        } catch {
            Haptics.error()
            self.error = error.friendlyMessage
        }
    }

    private func saveToRegistry() async {
        working = true
        defer { working = false }
        do {
            // Always store the 1-serving baseline; the portion calculator
            // rescales it on every open.
            try await SavedMealService.shared.save(
                name: name, description: description, kcal: kcal,
                proteinG: proteinG, carbsG: carbsG, fatG: fatG,
                ingredients: ingredients, steps: steps
            )
            Haptics.success()
            isSaved = true
            onChange()
        } catch {
            Haptics.error()
            self.error = error.friendlyMessage
        }
    }

    private func remove() async {
        guard case let .saved(id) = context else { return }
        working = true
        defer { working = false }
        do {
            try await SavedMealService.shared.delete(id: id)
            Haptics.success()
            onChange()
            dismiss()
        } catch {
            Haptics.error()
            self.error = error.friendlyMessage
        }
    }
}

#Preview("Suggestion") {
    MealIdeaDetailView(
        name: "Greek yogurt bowl",
        description: "High-protein breakfast with berries, honey and granola.",
        kcal: 420, proteinG: 32, carbsG: 48, fatG: 10,
        ingredients: [
            MealIngredient(name: "Greek yogurt", quantity: 200, unit: "g"),
            MealIngredient(name: "Mixed berries", quantity: 80, unit: "g"),
            MealIngredient(name: "Granola", quantity: 30, unit: "g"),
            MealIngredient(name: "Honey", quantity: 1, unit: "tbsp"),
        ],
        steps: [
            "Spoon the yogurt into a bowl.",
            "Top with berries and granola.",
            "Drizzle the honey over the top.",
        ],
        context: .suggestion
    )
    .preferredColorScheme(.dark)
}
