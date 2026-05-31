import SwiftUI

/// Form for logging a body-measurement check-in. Every field is optional — the
/// user fills only the metrics they track. Saving with nothing entered is
/// blocked so we never write an empty row.
struct AddMeasurementSheet: View {
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var waist = ""
    @State private var hip = ""
    @State private var chest = ""
    @State private var arm = ""
    @State private var thigh = ""
    @State private var bodyFat = ""
    @State private var saving = false
    @State private var error: String?

    private var hasAnyValue: Bool {
        [waist, hip, chest, arm, thigh, bodyFat]
            .contains { Double($0.replacingOccurrences(of: ",", with: ".")) != nil }
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("New measurement")
                        .font(Theme.Typo.h2)
                        .foregroundStyle(Theme.Palette.text)
                        .padding(.top, Theme.Spacing.md)

                    VStack(spacing: 0) {
                        field("Waist", unit: "cm", text: $waist)
                        divider
                        field("Hips", unit: "cm", text: $hip)
                        divider
                        field("Chest", unit: "cm", text: $chest)
                        divider
                        field("Arm", unit: "cm", text: $arm)
                        divider
                        field("Thigh", unit: "cm", text: $thigh)
                        divider
                        field("Body fat", unit: "%", text: $bodyFat)
                    }
                    .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radii.lg)
                            .stroke(Theme.Palette.border.opacity(0.7), lineWidth: 0.5)
                    )

                    VStack(spacing: Theme.Spacing.sm) {
                        PrimaryButton(title: saving ? "Saving…" : "Save") {
                            Task { await save() }
                        }
                        .disabled(!hasAnyValue || saving)
                        .opacity(hasAnyValue ? 1 : 0.5)
                        SecondaryButton(title: "Cancel") { dismiss() }
                    }
                    .padding(.top, Theme.Spacing.sm)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .alert("Error", isPresented: .constant(error != nil), actions: {
            Button("OK") { error = nil }
        }, message: { Text(error ?? "") })
    }

    private func field(_ label: String, unit: String, text: Binding<String>) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
                .frame(maxWidth: 90)
            Text(unit)
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
                .frame(width: 28, alignment: .leading)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Palette.border.opacity(0.6))
            .frame(height: 0.5)
            .padding(.leading, Theme.Spacing.md)
    }

    private func parse(_ s: String) -> Double? {
        Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await BodyMeasurementService.shared.save(
                waistCm: parse(waist), hipCm: parse(hip), chestCm: parse(chest),
                armCm: parse(arm), thighCm: parse(thigh), bodyFatPct: parse(bodyFat),
                notes: nil
            )
            Haptics.tapMedium()
            onSaved()
            dismiss()
        } catch {
            self.error = error.friendlyMessage
        }
    }
}
