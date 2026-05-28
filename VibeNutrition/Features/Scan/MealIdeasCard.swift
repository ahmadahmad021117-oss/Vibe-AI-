import SwiftUI
import Supabase

/// Home-page "Meal ideas" card. Used to live in a sheet that popped up after every
/// scan-save — that interrupted the flow, so suggestions now live inline on Home
/// where the user can glance at them without losing context.
struct MealIdeasCard: View {
    let remainingKcal: Int
    let remainingProtein: Double
    let remainingCarbs: Double
    let remainingFat: Double
    let dietaryPref: DietaryPref
    /// Goal direction is passed to the edge function so a person bulking gets
    /// calorie-dense ideas and a person cutting gets lean ones — without this,
    /// the model produced identical suggestions for both.
    let goalType: GoalType?

    struct Suggestion: Codable, Identifiable, Equatable {
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

    @State private var suggestions: [Suggestion] = []
    @State private var loading = false
    @State private var hasLoaded = false
    @State private var error: String?
    /// Names already shown to the user across this session — sent to the edge
    /// function so a refresh produces genuinely new ideas instead of the same
    /// three with minor wording tweaks.
    @State private var seenNames: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header
            content
        }
        .task { if !hasLoaded { await load() } }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Meal ideas")
                    .font(Theme.Typo.h3)
                    .foregroundStyle(Theme.Palette.text)
                Text("Matched to your remaining macros today.")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            Spacer()
            refreshButton
        }
    }

    private var refreshButton: some View {
        Button {
            Haptics.tapLight()
            Task { await load() }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.Palette.surface)
                    .frame(width: 32, height: 32)
                if loading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.Palette.textMuted)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textMuted)
                }
            }
        }
        .disabled(loading)
        .accessibilityLabel(loading ? "Loading new meal ideas" : "Refresh meal ideas")
    }

    @ViewBuilder
    private var content: some View {
        if loading && suggestions.isEmpty {
            loadingState
        } else if let error, suggestions.isEmpty {
            errorState(error)
        } else if suggestions.isEmpty {
            emptyState
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(suggestions) { s in
                        suggestionCard(s)
                    }
                }
            }
            .scrollClipDisabled()
            // Refresh leaves the existing cards on screen and only dims them,
            // so the user isn't staring at an empty placeholder for 2+ seconds.
            .opacity(loading ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.15), value: loading)
        }
    }

    private var loadingState: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView().tint(Theme.Palette.accent)
            Text("Coming up with ideas…")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
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
                    .foregroundStyle(Theme.Palette.textMuted)
                Text("Couldn't load ideas. Tap to retry.")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retry loading meal ideas")
    }

    private var emptyState: some View {
        Text("No ideas for now — you're on target.")
            .font(Theme.Typo.caption)
            .foregroundStyle(Theme.Palette.textMuted)
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func suggestionCard(_ s: Suggestion) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.name)
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
                    .lineLimit(2)
                Spacer(minLength: Theme.Spacing.xs)
                Text("\(s.kcal) kcal")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.accent)
            }
            Text(s.description)
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
                .lineLimit(3)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                macroDot("P", value: s.proteinG)
                macroDot("C", value: s.carbsG)
                macroDot("F", value: s.fatG)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 220, height: 150, alignment: .topLeading)
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

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            struct Body: Encodable {
                let remaining_kcal: Int
                let remaining_protein_g: Double
                let remaining_carbs_g: Double
                let remaining_fat_g: Double
                let dietary_pref: String
                let goal_type: String?
                let previous_names: [String]?
            }
            struct Resp: Decodable { let suggestions: [Suggestion] }

            let resp: Resp = try await SupabaseService.shared.functions.invoke(
                "suggest-meals",
                options: FunctionInvokeOptions(body: Body(
                    remaining_kcal: max(0, remainingKcal),
                    remaining_protein_g: max(0, remainingProtein),
                    remaining_carbs_g: max(0, remainingCarbs),
                    remaining_fat_g: max(0, remainingFat),
                    dietary_pref: dietaryPref.rawValue,
                    goal_type: goalType?.rawValue,
                    // Send only the last 12 names to keep the prompt small —
                    // enough to dodge repeats without bloating the request.
                    previous_names: seenNames.isEmpty ? nil : Array(seenNames.suffix(12))
                ))
            )
            suggestions = resp.suggestions
            // Track everything we've shown so far this session for the next refresh.
            seenNames.append(contentsOf: resp.suggestions.map(\.name))
            error = nil
            hasLoaded = true
        } catch {
            self.error = error.friendlyMessage
            hasLoaded = true
        }
    }
}

#Preview {
    MealIdeasCard(
        remainingKcal: 1200,
        remainingProtein: 80,
        remainingCarbs: 140,
        remainingFat: 35,
        dietaryPref: .normal,
        goalType: .loseWeight
    )
    .padding()
    .background(Theme.Palette.bg)
    .preferredColorScheme(.dark)
}
