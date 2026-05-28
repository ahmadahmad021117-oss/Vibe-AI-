import SwiftUI

/// Settings → "Choose your pace". Lists the 3 paces; tapping one previews it,
/// confirming it writes the change and recomputes the plan. The Progress / Home
/// screens pick up the new target via their next `vm.load()` (which fires on
/// the parent sheet's onDismiss).
struct PaceSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var current: Pace = .medium
    @State private var pendingPace: Pace?
    @State private var saving = false
    @State private var error: String?

    /// Called when the pace has been saved + the plan recomputed.
    var onSaved: (() -> Void)?

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("How fast do you want to move?")
                            .font(Theme.Typo.h2)
                            .foregroundStyle(Theme.Palette.text)
                            .padding(.top, Theme.Spacing.lg)
                        Text("Changing your pace adjusts your daily calorie target. Pick what you " +
                             "can stick with for several weeks — small steady wins beat fast-then-quit.")
                            .font(Theme.Typo.body)
                            .foregroundStyle(Theme.Palette.textMuted)

                        VStack(spacing: 0) {
                            ForEach(Array(Pace.allCases.enumerated()), id: \.element.id) { idx, p in
                                paceRow(p)
                                if idx < Pace.allCases.count - 1 {
                                    Divider().background(Theme.Palette.border.opacity(0.6))
                                }
                            }
                        }
                        .background(Theme.Palette.surface,
                                    in: RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radii.lg)
                                .stroke(Theme.Palette.border.opacity(0.7), lineWidth: 0.5)
                        )
                        .padding(.top, Theme.Spacing.sm)

                        if let error {
                            Text(error)
                                .font(Theme.Typo.caption)
                                .foregroundStyle(Theme.Palette.danger)
                        }

                        Spacer(minLength: Theme.Spacing.xl)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        .alert(
            "Change pace?",
            isPresented: Binding(
                get: { pendingPace != nil },
                set: { if !$0 { pendingPace = nil } }
            ),
            presenting: pendingPace
        ) { newPace in
            Button("Cancel", role: .cancel) { pendingPace = nil }
            Button("Apply") { Task { await commit(newPace) } }
        } message: { newPace in
            let weekly = String(format: "%.2f", newPace.weeklyKg)
            Text("This will retarget your daily calories for \(weekly) kg/week. " +
                 "Pace shouldn't be changed often — pick what you can stick with for several weeks.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Pace")
                .font(Theme.Typo.h2)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Button {
                Haptics.tapLight()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 30, height: 30)
                    .background(Theme.Palette.surface, in: Circle())
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Palette.bg)
    }

    // MARK: - Row

    private func paceRow(_ p: Pace) -> some View {
        let selected = current == p
        return Button {
            guard p != current else { return }
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
            .padding(.vertical, 12)
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

    // MARK: - Data

    private func load() async {
        let profile = try? await ProfileService.shared.fetchCurrent()
        current = profile?.pace ?? .medium
    }

    private func commit(_ newPace: Pace) async {
        pendingPace = nil
        saving = true
        defer { saving = false }
        do {
            try await ProfileService.shared.upsert(ProfilePatch(pace: newPace))
            current = newPace
            // Recompute calorie target so Home + Progress reflect the new pace.
            let gen = PlanGenerator()
            await gen.run(using: nil)
            Haptics.success()
            onSaved?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }
}

#Preview {
    PaceSheet()
        .preferredColorScheme(.dark)
}
