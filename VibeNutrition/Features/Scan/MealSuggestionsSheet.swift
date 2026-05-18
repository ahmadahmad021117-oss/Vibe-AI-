import SwiftUI
import Supabase

struct MealSuggestionsSheet: View {
    struct Remaining {
        let kcal: Int
        let protein: Double
        let carbs: Double
        let fat: Double
    }

    struct Suggestion: Codable, Identifiable {
        var id: String { name }
        let name: String
        let description: String
        let kcal: Int
        let proteinG: Double
        let carbsG: Double
        let fatG: Double

        enum CodingKeys: String, CodingKey {
            case name, description, kcal
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
        }
    }

    let remaining: Remaining

    @State private var suggestions: [Suggestion] = []
    @State private var loading = true
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header

                if loading {
                    VStack(spacing: Theme.Spacing.md) {
                        ProgressView().tint(Theme.Palette.accent)
                        Text("Coming up with ideas…")
                            .font(Theme.Typo.body)
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    Text(error)
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Palette.danger)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(suggestions) { s in
                                suggestionCard(s)
                            }
                        }
                    }
                }

                PrimaryButton(title: "Done") { dismiss() }
            }
            .padding(Theme.Spacing.lg)
        }
        .task { await load() }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next meal ideas")
                .font(Theme.Typo.h2)
                .foregroundStyle(Theme.Palette.text)
            Text("Matched to your remaining macros today.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
        }
    }

    private func suggestionCard(_ s: Suggestion) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(s.name)
                    .font(Theme.Typo.h3)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Text("\(s.kcal) kcal")
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.accent)
            }
            Text(s.description)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
            HStack(spacing: Theme.Spacing.md) {
                macroDot("P", value: s.proteinG)
                macroDot("C", value: s.carbsG)
                macroDot("F", value: s.fatG)
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
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Theme.Palette.surfaceHi, in: Capsule())
    }

    private func load() async {
        do {
            let profile = try await ProfileService.shared.fetchCurrent()
            let pref = profile?.dietaryPref ?? .normal

            // Compute "remaining for the rest of the day" relative to target.
            let latestTarget = try? await TargetService.shared.fetchLatest()
            let remainingKcal = max(0, (latestTarget?.kcal ?? remaining.kcal * 2) - remaining.kcal)
            let remainingProtein = max(0, Double(latestTarget?.proteinG ?? Int(remaining.protein * 2)) - remaining.protein)
            let remainingCarbs = max(0, Double(latestTarget?.carbsG ?? Int(remaining.carbs * 2)) - remaining.carbs)
            let remainingFat = max(0, Double(latestTarget?.fatG ?? Int(remaining.fat * 2)) - remaining.fat)

            struct Body: Encodable {
                let remaining_kcal: Int
                let remaining_protein_g: Double
                let remaining_carbs_g: Double
                let remaining_fat_g: Double
                let dietary_pref: String
            }

            struct Resp: Decodable { let suggestions: [Suggestion] }

            let resp: Resp = try await SupabaseService.shared.functions.invoke(
                "suggest-meals",
                options: FunctionInvokeOptions(body: Body(
                    remaining_kcal: remainingKcal,
                    remaining_protein_g: remainingProtein,
                    remaining_carbs_g: remainingCarbs,
                    remaining_fat_g: remainingFat,
                    dietary_pref: pref.rawValue
                ))
            )
            suggestions = resp.suggestions
            loading = false
        } catch {
            self.error = error.localizedDescription
            loading = false
        }
    }
}
