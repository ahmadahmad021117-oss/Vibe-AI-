import Foundation
import AuthenticationServices
import Supabase

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
        if session != nil {
            await validateRestoredSession()
        }
    }

    /// Confirms a restored session still maps to a live `auth.users` row.
    /// A deleted account (e.g. removed from another device via Delete-account)
    /// leaves a valid-looking JWT whose uid no longer exists: RLS accepts it
    /// (`auth.uid()` matches) but every FK insert into auth.users fails with
    /// "violates foreign key constraint", which the user hits mid-onboarding.
    /// We drop only the orphaned session — transient/offline errors keep it so
    /// offline launches still work.
    private func validateRestoredSession() async {
        do {
            _ = try await SupabaseService.shared.auth.user()
        } catch let error as AuthError {
            let rejected: Bool
            if case let .api(_, _, _, response) = error {
                rejected = [401, 403, 404].contains(response.statusCode)
            } else {
                rejected = error.errorCode == .userNotFound || error.errorCode == .sessionNotFound
            }
            if rejected {
                try? await SupabaseService.shared.auth.signOut(scope: .local)
                session = nil
                userId = nil
            }
        } catch {
            // Network/transient failure — keep the session.
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

    // MARK: - Sign out

    func signOut() async throws {
        try await SupabaseService.shared.auth.signOut()
        session = nil
        userId = nil
    }
}
