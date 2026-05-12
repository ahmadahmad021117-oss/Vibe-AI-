import SwiftUI

struct WeeklyProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var summary: WeeklyProgressService.Summary?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            if loading {
                ProgressView().tint(Theme.Palette.accent)
            } else if let s = summary {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        statsCard(s)
                        weightCard(s)
                        if s.adaptiveNudge {
                            adaptiveNudgeCard(s)
                        }
                        Spacer(minLength: Theme.Spacing.xl)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
            } else if let error {
                Text(error)
                    .font(Theme.Type.body)
                    .foregroundStyle(Theme.Palette.danger)
                    .padding(Theme.Spacing.lg)
            }
        }
        .task { await load() }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("This week")
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text("Progress")
                    .font(Theme.Type.h1)
                    .foregroundStyle(Theme.Palette.text)
            }
            Spacer()
            Button {
                Haptics.tapLight()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 36, height: 36)
                    .background(Theme.Palette.surface, in: Circle())
            }
        }
    }

    private func statsCard(_ s: WeeklyProgressService.Summary) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            statRow("Days logged", value: "\(s.logCount > 0 ? min(7, s.logCount) : 0) of 7")
            statRow("Avg kcal/day", value: "\(s.avgKcal)")
            statRow("Avg protein/day", value: "\(s.avgProteinG) g")
            statRow("Adherence", value: "\(s.adherencePct)%")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func weightCard(_ s: WeeklyProgressService.Summary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Weight")
                .font(Theme.Type.h3)
                .foregroundStyle(Theme.Palette.text)
            if let delta = s.actualDeltaKg {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(delta >= 0 ? "+" : "")\(String(format: "%.2f", delta)) kg")
                        .font(Theme.Type.numeralLG)
                        .foregroundStyle(Theme.Palette.text)
                    Text("vs last week")
                        .font(Theme.Type.body)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                if let expected = s.expectedDeltaKg {
                    Text("Expected: \(expected >= 0 ? "+" : "")\(String(format: "%.2f", expected)) kg/week")
                        .font(Theme.Type.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
            } else {
                Text("Log your weight twice this week to see a trend.")
                    .font(Theme.Type.body)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func adaptiveNudgeCard(_ s: WeeklyProgressService.Summary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Palette.warning)
                Text("Time to recalibrate")
                    .font(Theme.Type.h3)
                    .foregroundStyle(Theme.Palette.text)
            }
            Text("Your actual progress is off from what your plan expected. Tap to regenerate with updated weight.")
                .font(Theme.Type.body)
                .foregroundStyle(Theme.Palette.textMuted)
            PrimaryButton(title: "Recalibrate plan") {
                // The plan-generation flow re-runs and writes a fresh targets row.
                // Wiring lives in RootCoordinator; we just dismiss here.
                dismiss()
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radii.lg)
                .stroke(Theme.Palette.warning, lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radii.lg)
                        .fill(Theme.Palette.surface)
                )
        )
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Type.body)
                .foregroundStyle(Theme.Palette.textMuted)
            Spacer()
            Text(value)
                .font(Theme.Type.bodyBold)
                .foregroundStyle(Theme.Palette.text)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            summary = try await WeeklyProgressService.shared.fetch()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
