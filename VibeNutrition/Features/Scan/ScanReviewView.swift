import SwiftUI

struct ScanReviewView: View {
    let imageData: Data?
    let imagePath: String?
    let initialFood: AnalyzedFood

    @State private var items: [FoodItem]
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

                    // Reserve space so the last food row doesn't tuck behind
                    // the floating Save / Retake actions bar.
                    Spacer(minLength: 180)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Looks like…")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
            Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                .font(Theme.Typo.h2)
                .foregroundStyle(Theme.Palette.text)
        }
    }

    private var totalsCard: some View {
        let t = totals()
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Total")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)

            // Calories get a full-width line of their own so big numbers
            // (e.g. 1,138 kcal) never wrap or truncate; they scale down only
            // in extreme cases.
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text("🔥 \(t.kcal.formatted())")
                    .font(Theme.Typo.numeralLG)
                    .foregroundStyle(Theme.Palette.text)
                    .contentTransition(.numericText(value: Double(t.kcal)))
                Text("kcal")
                    .font(Theme.Typo.h3)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)

            Divider().overlay(Theme.Palette.border)
                .padding(.vertical, Theme.Spacing.xs)

            HStack(spacing: Theme.Spacing.sm) {
                macroTotal("🥩", "Protein", grams: t.protein)
                macroTotal("🍞", "Carbs", grams: t.carbs)
                macroTotal("🥑", "Fat", grams: t.fat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func macroTotal(_ emoji: String, _ label: String, grams: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(emoji) \(Int(grams.rounded()))g")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: grams))
            Text(label)
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var itemsList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array($items.enumerated()), id: \.offset) { index, $item in
                let original = initialFood.items.indices.contains(index)
                    ? initialFood.items[index]
                    : item
                FoodItemRow(item: $item, original: original)
            }
        }
    }

    private var actionsBar: some View {
        // Layered: short fade above the controls, solid bg behind them, so
        // the last food row never bleeds through the Save / Retake buttons.
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Theme.Palette.bg.opacity(0), Theme.Palette.bg],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)

            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton(title: saving ? "Saving…" : "Save to today", isEnabled: !saving) {
                    Task { await save() }
                }
                SecondaryButton(title: "Retake") { onRetake() }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.lg)
            .background(Theme.Palette.bg)
        }
    }

    private func totals() -> (kcal: Int, protein: Double, carbs: Double, fat: Double) {
        items.reduce((0, 0.0, 0.0, 0.0)) { acc, item in
            (acc.0 + item.kcal, acc.1 + item.proteinG, acc.2 + item.carbsG, acc.3 + item.fatG)
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await FoodLogService.shared.write(items: items, imagePath: imagePath, source: .scan)
            Haptics.success()
            onDone()
        } catch {
            Haptics.error()
            errorMessage = error.friendlyMessage
        }
    }
}

private struct FoodItemRow: View {
    @Binding var item: FoodItem
    /// The original (un-edited) item from the AI scan. The slider scales relative to this,
    /// so successive adjustments do not compound.
    let original: FoodItem

    /// Hard caps so a user can never scroll into nonsense values.
    /// Range derives from the ORIGINAL grams, not the current grams.
    private static let maxKcalPerItem: Int = 10_000
    private static let maxGramsPerItem: Double = 5_000

    private var sliderRange: ClosedRange<Double> {
        // Allow trimming down to a small portion or expanding up to 4× the original,
        // clamped to a sane minimum of 10g and an upper bound that respects both
        // an absolute gram cap AND the per-item 10,000-kcal cap.
        let lower = max(10, original.grams * 0.25)
        let kcalCapGrams = original.kcal > 0
            ? Double(Self.maxKcalPerItem) / Double(original.kcal) * original.grams
            : Self.maxGramsPerItem
        let upper = min(Self.maxGramsPerItem, max(original.grams * 4, 200), kcalCapGrams)
        return lower...max(lower + 1, upper)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(item.name.capitalized)
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Text("\(Int(item.grams.rounded()))g")
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.accent)
                    .contentTransition(.numericText(value: item.grams))
            }

            Slider(value: gramsBinding, in: sliderRange, step: 5)
                .tint(Theme.Palette.accent)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    /// Adjust grams → scale all per-item macros & micros relative to the ORIGINAL AI estimate.
    /// Scaling relative to the original (not the current) prevents compounding to absurd values
    /// when the user drags the slider back and forth.
    private var gramsBinding: Binding<Double> {
        Binding(
            get: { item.grams },
            set: { rawGrams in
                let newGrams = min(Self.maxGramsPerItem, max(0, rawGrams))
                guard original.grams > 0 else { return }
                let scale = newGrams / original.grams
                Haptics.select()
                item.grams = newGrams
                // Recompute from original to avoid compounding; clamp kcal to 0…10000.
                let kcal = Int((Double(original.kcal) * scale).rounded())
                item.kcal = min(Self.maxKcalPerItem, max(0, kcal))
                item.proteinG = max(0, (original.proteinG * scale * 10).rounded() / 10)
                item.carbsG   = max(0, (original.carbsG   * scale * 10).rounded() / 10)
                item.fatG     = max(0, (original.fatG     * scale * 10).rounded() / 10)
                let scaledMicros = original.micros.scaled(by: scale)
                item.vitaminDMcg   = scaledMicros.vitaminDMcg
                item.vitaminB12Mcg = scaledMicros.vitaminB12Mcg
                item.vitaminCMg    = scaledMicros.vitaminCMg
                item.magnesiumMg   = scaledMicros.magnesiumMg
                item.ironMg        = scaledMicros.ironMg
                item.zincMg        = scaledMicros.zincMg
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
