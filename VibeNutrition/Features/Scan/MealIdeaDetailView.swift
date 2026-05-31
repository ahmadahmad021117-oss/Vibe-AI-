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
    let context: Context
    /// Called after a successful log or registry change so callers can refresh.
    var onChange: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var isSaved = false
    @State private var working = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    headerBlock
                    if !description.isEmpty { descriptionBlock }
                    macrosBlock
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
            Text("\(kcal) kcal")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.accent)
        }
    }

    private var descriptionBlock: some View {
        Text(description)
            .font(Theme.Typo.body)
            .foregroundStyle(Theme.Palette.textMuted)
    }

    private var macrosBlock: some View {
        VStack(spacing: Theme.Spacing.sm) {
            macroRow("Protein", grams: proteinG)
            macroRow("Carbs", grams: carbsG)
            macroRow("Fat", grams: fatG)
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
        let item = FoodItem(
            name: name, grams: 0, kcal: kcal,
            proteinG: proteinG, carbsG: carbsG, fatG: fatG, confidence: nil
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
            try await SavedMealService.shared.save(
                name: name, description: description, kcal: kcal,
                proteinG: proteinG, carbsG: carbsG, fatG: fatG
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
        context: .suggestion
    )
    .preferredColorScheme(.dark)
}
