import SwiftUI

/// GDPR-style marketing email opt-in sheet. The consent box is **unchecked by default**.
/// Save is enabled if the user is opting out, OR if they're opting in with a valid email.
struct MarketingEmailSheet: View {
    let initialEmail: String
    let initialOptIn: Bool
    let onSave: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var optIn: Bool

    init(initialEmail: String, initialOptIn: Bool, onSave: @escaping (String, Bool) -> Void) {
        self.initialEmail = initialEmail
        self.initialOptIn = initialOptIn
        self.onSave = onSave
        _email = State(initialValue: initialEmail)
        _optIn = State(initialValue: initialOptIn)
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                emailField
                consentRow
                Spacer()
                PrimaryButton(
                    title: "Save",
                    isEnabled: !optIn || isValidEmail(email)
                ) {
                    onSave(email, optIn)
                    dismiss()
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    private var header: some View {
        HStack {
            Text("Marketing email")
                .font(Theme.Typo.h2)
                .foregroundStyle(Theme.Palette.text)
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

    private var emailField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("EMAIL")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
            TextField(
                "",
                text: $email,
                prompt: Text("you@example.com").foregroundStyle(Theme.Palette.textDim)
            )
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocapitalization(.none)
            .padding()
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.md))
            .foregroundStyle(Theme.Palette.text)
        }
    }

    private var consentRow: some View {
        Button {
            Haptics.select()
            optIn.toggle()
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: optIn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(optIn ? Theme.Palette.accent : Theme.Palette.textMuted)
                VStack(alignment: .leading, spacing: 4) {
                    Text("I'd like to receive updates and tips from VibeCal")
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Palette.text)
                        .multilineTextAlignment(.leading)
                    Text("You can withdraw consent at any time from this screen. We won't send anything until you opt in.")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
        .accessibilityLabel("Marketing email opt-in")
        .accessibilityValue(optIn ? "Opted in" : "Not opted in")
        .accessibilityAddTraits(.isButton)
    }

    private func isValidEmail(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        return s.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }
}
