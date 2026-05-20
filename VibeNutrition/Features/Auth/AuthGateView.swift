import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthGateView: View {
    let onAuthenticated: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isLoading = false
    @State private var currentNonce: String?
    /// Email form starts collapsed — most users sign in with Apple. Reveals on tap.
    @State private var showingEmailForm = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                hero
                Spacer()

                // Primary CTA: Sign in with Apple. Always visible, always dominant.
                SignInWithAppleButton(
                    onRequest: configureAppleRequest,
                    onCompletion: handleAppleCompletion
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 56)
                .cornerRadius(Theme.Radii.lg)

                if showingEmailForm {
                    emailForm
                } else {
                    revealEmailButton
                }

                Spacer().frame(height: Theme.Spacing.lg)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .animation(Theme.Motion.spring, value: showingEmailForm)
        }
    }

    private var hero: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 56, weight: .heavy))
                .foregroundStyle(Theme.Gradients.accent)
            Text("Welcome to VibeCal")
                .font(Theme.Typo.h1)
                .foregroundStyle(Theme.Palette.text)
            Text("Your AI calorie coach.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
        }
    }

    private var revealEmailButton: some View {
        Button {
            Haptics.tapLight()
            showingEmailForm = true
        } label: {
            Text("Continue with email")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.textMuted)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .accessibilityLabel("Continue with email instead")
    }

    private var emailForm: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // "or use email" divider
            HStack(spacing: Theme.Spacing.md) {
                Rectangle()
                    .fill(Theme.Palette.border)
                    .frame(height: 1)
                Text("or use email")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Rectangle()
                    .fill(Theme.Palette.border)
                    .frame(height: 1)
            }
            .padding(.bottom, Theme.Spacing.xs)

            TextField("", text: $email, prompt: Text("Email").foregroundStyle(Theme.Palette.textDim))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.md))
                .foregroundStyle(Theme.Palette.text)

            SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Theme.Palette.textDim))
                .textContentType(.password)
                .padding()
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.md))
                .foregroundStyle(Theme.Palette.text)

            if let error {
                Text(error)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.danger)
                    .multilineTextAlignment(.center)
            }

            SecondaryButton(title: isLoading ? "Signing in…" : "Continue") {
                Task { await emailSignIn() }
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.5 : 1)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func emailSignIn() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService.shared.signIn(email: email, password: password)
            onAuthenticated()
        } catch {
            // Fall back to sign-up on "Invalid login credentials" so first-launch flows work.
            do {
                try await AuthService.shared.signUp(email: email, password: password)
                try await AuthService.shared.signIn(email: email, password: password)
                onAuthenticated()
            } catch {
                self.error = error.friendlyMessage
            }
        }
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = cred.identityToken,
                let token = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                error = "Apple sign-in failed."
                return
            }
            Task {
                do {
                    try await AuthService.shared.signInWithApple(idToken: token, nonce: nonce)
                    onAuthenticated()
                } catch {
                    self.error = error.friendlyMessage
                }
            }
        case .failure(let err):
            // Cancellation is not an error worth surfacing.
            if (err as NSError).code != ASAuthorizationError.canceled.rawValue {
                error = err.friendlyMessage
            }
        }
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce: \(status)")
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    AuthGateView(onAuthenticated: {})
        .preferredColorScheme(.dark)
}
