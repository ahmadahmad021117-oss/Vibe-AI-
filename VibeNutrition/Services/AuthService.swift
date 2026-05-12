import Foundation
import AuthenticationServices
import Supabase
import GoogleSignIn
import UIKit

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var session: Session?
    private(set) var userId: UUID?
    var isAuthenticated: Bool { session != nil }

    private var authListenerTask: Task<Void, Never>?

    private init() {
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        do {
            session = try await SupabaseService.shared.auth.session
            userId = session?.user.id
        } catch {
            session = nil
        }
        authListenerTask = Task { [weak self] in
            for await change in SupabaseService.shared.auth.authStateChanges {
                guard let self else { return }
                self.session = change.session
                self.userId = change.session?.user.id
            }
        }
    }

    // MARK: - Email

    func signUp(email: String, password: String) async throws {
        _ = try await SupabaseService.shared.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        let response = try await SupabaseService.shared.auth.signIn(email: email, password: password)
        session = response
        userId = response.user.id
    }

    // MARK: - Sign in with Apple

    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await SupabaseService.shared.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
        self.session = session
        self.userId = session.user.id
    }

    // MARK: - Google

    func signInWithGoogle(presentingVC: UIViewController) async throws {
        let config = GIDConfiguration(clientID: AppConfig.googleClientID)
        GIDSignIn.sharedInstance.configuration = config
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google returned no id token"])
        }
        let session = try await SupabaseService.shared.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .google, idToken: idToken)
        )
        self.session = session
        self.userId = session.user.id
    }

    // MARK: - Sign out

    func signOut() async throws {
        try await SupabaseService.shared.auth.signOut()
        session = nil
        userId = nil
    }
}
