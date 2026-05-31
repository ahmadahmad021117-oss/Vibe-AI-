import SwiftUI

/// History of body-measurement check-ins with an add button. Presented as a
/// sheet from the Progress tab's Body section.
struct MeasurementsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var measurements: [BodyMeasurement] = []
    @State private var loading = true
    @State private var showingAdd = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if loading {
                        ProgressView().tint(Theme.Palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xl)
                    } else if measurements.isEmpty {
                        emptyState
                    } else {
                        ForEach(measurements) { m in
                            row(m)
                        }
                    }
                    Spacer(minLength: 100)
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
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Add measurement") { showingAdd = true }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingAdd) {
            AddMeasurementSheet { Task { await load() } }
        }
        .alert("Error", isPresented: .constant(error != nil), actions: {
            Button("OK") { error = nil }
        }, message: { Text(error ?? "") })
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Body")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text("Measurements")
                    .font(Theme.Typo.h2)
                    .foregroundStyle(Theme.Palette.text)
            }
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
    }

    private func row(_ m: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateString(m.measuredAt))
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Button {
                    Haptics.tapLight()
                    Task { await delete(m) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.danger)
                        .frame(width: 30, height: 30)
                        .background(Theme.Palette.surfaceHi, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete measurement from \(dateString(m.measuredAt))")
            }
            FlexChips(items: chips(m))
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func chips(_ m: BodyMeasurement) -> [String] {
        var out: [String] = []
        if let v = m.waistCm { out.append("Waist \(v.grouped(1)) cm") }
        if let v = m.hipCm { out.append("Hips \(v.grouped(1)) cm") }
        if let v = m.chestCm { out.append("Chest \(v.grouped(1)) cm") }
        if let v = m.armCm { out.append("Arm \(v.grouped(1)) cm") }
        if let v = m.thighCm { out.append("Thigh \(v.grouped(1)) cm") }
        if let v = m.bodyFatPct { out.append("Body fat \(v.grouped(1))%") }
        return out
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "ruler")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
            Text("Track your measurements")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
            Text("Waist, hips, body fat and more. The scale isn't the whole story.")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            measurements = try await BodyMeasurementService.shared.list()
                .filter { !$0.isEmpty }
        } catch {
            self.error = error.friendlyMessage
        }
    }

    private func delete(_ m: BodyMeasurement) async {
        do {
            try await BodyMeasurementService.shared.delete(id: m.id)
            measurements.removeAll { $0.id == m.id }
        } catch {
            self.error = error.friendlyMessage
        }
    }
}

/// Simple wrapping chip row used to show the metrics recorded on a measurement.
private struct FlexChips: View {
    let items: [String]

    var body: some View {
        // A lightweight flow layout — chips wrap to the next line as needed.
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { text in
                Text(text)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.Palette.surfaceHi, in: Capsule())
            }
        }
    }
}

/// Minimal flow layout (iOS 16+ `Layout`). Wraps subviews onto new rows when
/// they exceed the proposed width.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
