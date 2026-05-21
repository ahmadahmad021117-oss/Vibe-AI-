import SwiftUI

/// "Progress" tab. Houses the long-running plan signals: current weight, goal weight, pace,
/// and the projection chart. Pace changes are gated behind a confirmation alert so the user
/// can't accidentally swing their calorie target with a single tap.
struct ProgressTabView: View {
    @Bindable var vm: DashboardViewModel

    @State private var showingProfile = false
    @State private var showingEditWeight = false
    @State private var showingEditGoalWeight = false

    /// Pace the user tapped, awaiting confirmation. nil = no pending change.
    @State private var pendingPace: Pace?
    @State private var saving = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    weightCard
                    paceCard
                    projectionCard
                    Spacer(minLength: Theme.Spacing.xl)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Palette.bg)
            }
        }
        .task { if vm.target == nil { await vm.load() } }
        .sheet(isPresented: $showingProfile) { ProfileView() }
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
        .alert(
            "Change pace?",
            isPresented: Binding(
                get: { pendingPace != nil },
                set: { if !$0 { pendingPace = nil } }
            ),
            presenting: pendingPace
        ) { newPace in
            Button("Cancel", role: .cancel) { pendingPace = nil }
            Button("Apply") {
                Task { await commitPace(newPace) }
            }
        } message: { newPace in
            Text(confirmationMessage(for: newPace))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Progress")
                .font(Theme.Typo.h2)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Button {
                Haptics.tapLight()
                showingProfile = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Weight card (two tiles)

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
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

    /// Vertical-stack tile so the label never wraps and the value is the visual anchor (Apple Health style).
    private func weightTile(iconSystem: String, iconTint: Color, label: String, kg: Double?, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tapLight()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: iconSystem)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(iconTint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(label)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textDim)
                }
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

    // MARK: - Pace card

    private var paceCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                sectionLabel("Pace")
                Spacer()
                Text(vm.pace.subtitle)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            VStack(spacing: 0) {
                ForEach(Array(Pace.allCases.enumerated()), id: \.element.id) { idx, p in
                    paceRow(p)
                    if idx < Pace.allCases.count - 1 {
                        Divider().background(Theme.Palette.border.opacity(0.6))
                    }
                }
            }
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radii.lg)
                    .stroke(Theme.Palette.border.opacity(0.7), lineWidth: 0.5)
            )
            Text("Changing your pace adjusts your daily calorie target.")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textDim)
                .padding(.leading, 4)
        }
    }

    private func paceRow(_ p: Pace) -> some View {
        let selected = vm.pace == p
        return Button {
            guard p != vm.pace else { return }
            Haptics.select()
            pendingPace = p
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: paceIcon(p))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(paceTint(p), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.label)
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Palette.text)
                    Text(p.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(saving)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func paceIcon(_ p: Pace) -> String {
        switch p {
        case .slow:   return "tortoise.fill"
        case .medium: return "figure.walk"
        case .fast:   return "hare.fill"
        }
    }

    private func paceTint(_ p: Pace) -> Color {
        switch p {
        case .slow:   return .teal
        case .medium: return .blue
        case .fast:   return .orange
        }
    }

    private func confirmationMessage(for newPace: Pace) -> String {
        let weekly = String(format: "%.2f", newPace.weeklyKg)
        return "This will retarget your daily calories for \(weekly) kg/week. Pace shouldn't be changed often — pick what you can stick with for several weeks."
    }

    private func commitPace(_ newPace: Pace) async {
        pendingPace = nil
        saving = true
        defer { saving = false }
        await vm.savePace(newPace)
        Haptics.success()
    }

    // MARK: - Projection card

    @ViewBuilder
    private var projectionCard: some View {
        if let current = vm.latestWeight?.weightKg ?? vm.latestGoal?.startWeightKg,
           let goal = vm.latestGoal?.goalWeightKg {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
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
