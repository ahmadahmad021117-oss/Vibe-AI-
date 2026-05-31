import SwiftUI

/// The user's saved-meal registry. Lists meals kept from the Meal Ideas card;
/// each row opens a detail sheet to log it to today or remove it.
struct SavedMealsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var meals: [SavedMeal] = []
    @State private var loading = true
    @State private var error: String?
    @State private var selected: SavedMeal?

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                content
            }
            .padding(Theme.Spacing.lg)
        }
        .task { await load() }
        .sheet(item: $selected, onDismiss: { Task { await load() } }) { meal in
            MealIdeaDetailView(
                name: meal.name,
                description: meal.description,
                kcal: meal.kcal,
                proteinG: meal.proteinG,
                carbsG: meal.carbsG,
                fatG: meal.fatG,
                ingredients: meal.ingredients,
                steps: meal.steps,
                context: .saved(id: meal.id)
            )
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Saved meals")
                    .font(Theme.Typo.h2)
                    .foregroundStyle(Theme.Palette.text)
                Text("Your meal registry — tap one to log it again.")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            Spacer()
            Button {
                Haptics.tapLight()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .accessibilityLabel("Close")
        }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            Spacer()
            ProgressView().tint(Theme.Palette.accent)
                .frame(maxWidth: .infinity)
            Spacer()
        } else if let error {
            errorState(error)
        } else if meals.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(meals) { meal in
                        Button {
                            Haptics.tapLight()
                            selected = meal
                        } label: {
                            mealRow(meal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func mealRow(_ meal: SavedMeal) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(meal.name)
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
                    .lineLimit(2)
                Spacer(minLength: Theme.Spacing.xs)
                Text("\(meal.kcal) kcal")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.accent)
            }
            if !meal.description.isEmpty {
                Text(meal.description)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                    .lineLimit(2)
            }
            HStack(spacing: 6) {
                macroDot("P", value: meal.proteinG)
                macroDot("C", value: meal.carbsG)
                macroDot("F", value: meal.fatG)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textDim)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func macroDot(_ label: String, value: Double) -> some View {
        Text("\(label) \(Int(value.rounded()))g")
            .font(Theme.Typo.caption)
            .foregroundStyle(Theme.Palette.textMuted)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(Theme.Palette.surfaceHi, in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "bookmark")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.Palette.textMuted)
            Text("No saved meals yet")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
            Text("Tap a meal idea on your home screen and save it here to log it again later.")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func errorState(_ message: String) -> some View {
        Button {
            Haptics.tapLight()
            Task { await load() }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                Text("Couldn't load saved meals. Tap to retry.")
                    .font(Theme.Typo.caption)
                Spacer()
            }
            .foregroundStyle(Theme.Palette.textMuted)
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retry loading saved meals")
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            meals = try await SavedMealService.shared.list()
            error = nil
        } catch {
            self.error = error.friendlyMessage
        }
    }
}

#Preview {
    SavedMealsView()
        .preferredColorScheme(.dark)
}
