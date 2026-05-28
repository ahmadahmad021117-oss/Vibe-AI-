import SwiftUI

/// "Progress" tab. Scrolls vertically — the page used to be locked to one
/// screen, but adding the 7-day calorie chart pushed content below the tab bar
/// on smaller phones. The weight projection's pin drag is scoped to the pin
/// itself (not the whole chart), so it doesn't conflict with the page scroll.
/// Houses the long-running plan signals: current/goal weight, projection,
/// calorie history. Pace lives in Settings now (deliberate friction: changing
/// it adjusts the calorie target).
struct ProgressTabView: View {
    @Bindable var vm: DashboardViewModel

    @State private var showingProfile = false
    @State private var showingEditWeight = false
    @State private var showingEditGoalWeight = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            // Vertical-only scroll. The `.scrollBounceBehavior(.basedOnSize, axes: .horizontal)`
            // kills the horizontal rubber-band drift that SwiftUI's ScrollView
            // still allows even when the axes are locked to `.vertical`.
            // `containerRelativeFrame(.horizontal)` pins the content width to
            // the scroll view's width, so nothing can ever exceed the viewport.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    weightCard
                    projectionCard
                    calorieHistoryCard
                    // The system tab bar sits over the bottom — pad so the
                    // calorie chart doesn't end up half-hidden behind it.
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .containerRelativeFrame(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .refreshable { await vm.load() }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Palette.bg)
            }
        }
        .task { if vm.target == nil { await vm.load() } }
        // When the Settings sheet closes the user may have just changed their pace,
        // so refresh to pick up the new calorie target and pace label.
        .sheet(isPresented: $showingProfile, onDismiss: { Task { await vm.load() } }) {
            ProfileView()
        }
        .sheet(isPresented: $showingEditWeight) {
            EditWeightSheet(
                title: "Update current weight",
                initialKg: vm.latestWeight?.weightKg ?? vm.latestGoal?.startWeightKg ?? 70
            ) { newKg in
                Task { await vm.saveCurrentWeight(newKg) }
            }
        }
        .sheet(isPresented: $showingEditGoalWeight) {
            EditWeightSheet(
                title: "Update goal weight",
                initialKg: vm.latestGoal?.goalWeightKg ?? 70
            ) { newKg in
                Task { await vm.saveGoalWeight(newKg) }
            }
        }
    }

    // MARK: - Header

    /// Mirrors DashboardView.header exactly — same caption + h2 + 28pt profile icon
    /// placement so swiping between tabs feels continuous.
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your plan")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text("Progress")
                    .font(Theme.Typo.h2)
                    .foregroundStyle(Theme.Palette.text)
            }
            Spacer()
            Button {
                Haptics.tapLight()
                showingProfile = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Weight tiles

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Weight")
            HStack(spacing: Theme.Spacing.sm) {
                weightTile(
                    iconSystem: "scalemass.fill",
                    iconTint: .blue,
                    label: "Current",
                    kg: vm.latestWeight?.weightKg ?? vm.latestGoal?.startWeightKg
                ) {
                    showingEditWeight = true
                }
                weightTile(
                    iconSystem: "target",
                    iconTint: .green,
                    label: "Goal",
                    kg: vm.latestGoal?.goalWeightKg
                ) {
                    showingEditGoalWeight = true
                }
            }
        }
    }

    /// Vertical-stack tile. The icon + pencil sit in a top row, the label gets its own
    /// dedicated line, and the value anchors the bottom. lineLimit(1) plus
    /// minimumScaleFactor guarantee single-line labels even on the narrowest iPhone.
    private func weightTile(iconSystem: String, iconTint: Color, label: String, kg: Double?, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tapLight()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: iconSystem)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(iconTint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textDim)
                }
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(kgValueString(kg))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.text)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("kg")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textMuted)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radii.lg)
                    .stroke(Theme.Palette.border.opacity(0.7), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) weight \(kgValueString(kg)) kilograms. Tap to edit.")
    }

    private func kgValueString(_ kg: Double?) -> String {
        guard let kg else { return "—" }
        return String(format: "%.1f", kg)
    }

    // MARK: - Projection

    @ViewBuilder
    private var projectionCard: some View {
        if let current = vm.latestWeight?.weightKg ?? vm.latestGoal?.startWeightKg,
           let goal = vm.latestGoal?.goalWeightKg {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Projection")
                WeightProjectionChart(
                    currentKg: current,
                    goalKg: goal,
                    pace: vm.pace,
                    heightCm: vm.profile?.heightCm
                )
            }
        }
    }

    // MARK: - Calorie history

    /// Goal-aware 7-day intake chart. Skipped until we have a target — without
    /// it, "on plan" colouring is meaningless. Empty history is fine to show:
    /// a row of muted bars at zero communicates "no logs yet, start tracking."
    @ViewBuilder
    private var calorieHistoryCard: some View {
        if let t = vm.target {
            CalorieWeekChart(
                history: vm.weeklyKcalHistory,
                targetKcal: t.kcal,
                direction: vm.latestGoal?.type.direction
            )
        }
    }

    // MARK: - Building blocks

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.Palette.textMuted)
            .padding(.leading, 4)
    }
}

#Preview {
    ProgressTabView(vm: DashboardViewModel())
        .preferredColorScheme(.dark)
}
