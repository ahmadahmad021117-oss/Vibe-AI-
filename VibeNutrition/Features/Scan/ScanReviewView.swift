import SwiftUI

struct ScanReviewView: View {
    let imageData: Data?
    let imagePath: String?
    let initialFood: AnalyzedFood

    @State private var items: [FoodItem]
    @State private var showingSuggestions = false
    @State private var saving = false
    @State private var errorMessage: String?

    let onDone: () -> Void
    let onRetake: () -> Void

    init(imageData: Data?, imagePath: String?, food: AnalyzedFood,
         onDone: @escaping () -> Void, onRetake: @escaping () -> Void) {
        self.imageData = imageData
        self.imagePath = imagePath
        self.initialFood = food
        self._items = State(initialValue: food.items)
        self.onDone = onDone
        self.onRetake = onRetake
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    header

                    if let data = imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.lg))
                    }

                    totalsCard
                    itemsList

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }

            VStack {
                Spacer()
                actionsBar
            }
        }
        .alert("Save failed", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
        .sheet(isPresented: $showingSuggestions) {
            MealSuggestionsSheet(remaining: remainingMacros())
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Looks like…")
                .font(Theme.Type.caption)
                .foregroundStyle(Theme.Palette.textMuted)
            Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                .font(Theme.Type.h2)
                .foregroundStyle(Theme.Palette.text)
        }
    }

    private var totalsCard: some View {
        let t = totals()
        return HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total")
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text("\(t.kcal) kcal")
                    .font(Theme.Type.h2)
                    .foregroundStyle(Theme.Palette.text)
            }
            Spacer()
            HStack(spacing: Theme.Spacing.md) {
                macroTotal("P", grams: t.protein)
                macroTotal("C", grams: t.carbs)
                macroTotal("F", grams: t.fat)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func macroTotal(_ label: String, grams: Double) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(Theme.Type.caption)
                .foregroundStyle(Theme.Palette.textMuted)
            Text("\(Int(grams.rounded()))g")
                .font(Theme.Type.bodyBold)
                .foregroundStyle(Theme.Palette.text)
        }
        .frame(minWidth: 36)
    }

    private var itemsList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach($items, id: \.name) { $item in
                FoodItemRow(item: $item)
            }
        }
    }

    private var actionsBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PrimaryButton(title: saving ? "Saving…" : "Save to today", isEnabled: !saving) {
                Task { await save() }
            }
            SecondaryButton(title: "Retake") { onRetake() }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [Theme.Palette.bg.opacity(0), Theme.Palette.bg],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false),
            alignment: .bottom
        )
    }

    private func totals() -> (kcal: Int, protein: Double, carbs: Double, fat: Double) {
        items.reduce((0, 0.0, 0.0, 0.0)) { acc, item in
            (acc.0 + item.kcal, acc.1 + item.proteinG, acc.2 + item.carbsG, acc.3 + item.fatG)
        }
    }

    private func remainingMacros() -> MealSuggestionsSheet.Remaining {
        let t = totals()
        return .init(kcal: t.kcal, protein: t.protein, carbs: t.carbs, fat: t.fat)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await FoodLogService.shared.write(items: items, imagePath: imagePath, source: .scan)
            Haptics.success()
            let profile = try? await ProfileService.shared.fetchCurrent()
            if profile?.mealSuggestionsEnabled == true {
                showingSuggestions = true
            } else {
                onDone()
            }
        } catch {
            Haptics.error()
            errorMessage = error.friendlyMessage
        }
    }
}

private struct FoodItemRow: View {
    @Binding var item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(item.name.capitalized)
                    .font(Theme.Type.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Text("\(Int(item.grams.rounded()))g")
                    .font(Theme.Type.bodyBold)
                    .foregroundStyle(Theme.Palette.accent)
                    .contentTransition(.numericText(value: item.grams))
            }

            Slider(value: gramsBinding, in: max(10, item.grams * 0.25)...max(item.grams * 2.5, 100), step: 5)
                .tint(Theme.Palette.accent)

            HStack(spacing: Theme.Spacing.md) {
                Text("\(item.kcal) kcal")
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Spacer()
                Text("P \(Int(item.proteinG.rounded()))g")
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text("C \(Int(item.carbsG.rounded()))g")
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text("F \(Int(item.fatG.rounded()))g")
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    /// Adjust grams → scale all per-item macros proportionally relative to the original AI estimate.
    private var gramsBinding: Binding<Double> {
        Binding(
            get: { item.grams },
            set: { newGrams in
                guard item.grams > 0 else { return }
                let scale = newGrams / item.grams
                Haptics.select()
                item.grams = newGrams
                item.kcal = Int((Double(item.kcal) * scale).rounded())
                item.proteinG = (item.proteinG * scale * 10).rounded() / 10
                item.carbsG = (item.carbsG * scale * 10).rounded() / 10
                item.fatG = (item.fatG * scale * 10).rounded() / 10
            }
        )
    }
}

#Preview {
    let food = AnalyzedFood(items: [
        FoodItem(name: "Grilled chicken breast", grams: 180, kcal: 297,
                 proteinG: 56, carbsG: 0, fatG: 6.5, confidence: 0.92),
        FoodItem(name: "Steamed broccoli", grams: 120, kcal: 41,
                 proteinG: 3.4, carbsG: 8.4, fatG: 0.4, confidence: 0.85),
    ])
    return ScanReviewView(imageData: nil, imagePath: nil, food: food,
                          onDone: {}, onRetake: {})
        .preferredColorScheme(.dark)
}
