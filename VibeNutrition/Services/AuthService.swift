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
        // Listen first: with `emitLocalSessionAsInitialSession` the SDK delivers
        // the stored session right away (even offline), and drives every later
        // sign-in / token-refresh / sign-out. We only clear our local state on an
        // explicit SIGNED_OUT — never on a missing session from a transient event.
        authListenerTask = Task { [weak self] in
            for await change in SupabaseService.shared.auth.authStateChanges {
                guard let self else { return }
                if change.event == .signedOut {
                    self.session = nil
                    self.userId = nil
                } else if let session = change.session {
                    self.session = session
                    self.userId = session.user.id
                }
            }
        }

        do {
            // Refreshes the token if the access token has expired. With a valid
            // stored refresh token this succeeds even days later.
            let restored = try await SupabaseService.shared.auth.session
            session = restored
            userId = restored.user.id
            await validateRestoredSession()
        } catch {
            // Offline / transient failure — do NOT sign the user out. The stored
            // session was already surfaced by the listener above, and auto-refresh
            // will recover the token once the network is back.
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
            // Only a *confirmed* "this account no longer exists" should drop the
            // session (the deleted-from-another-device case above). 401/403 are
            // token-timing / permission blips that auto-refresh recovers, and a
            // genuinely dead session is cleaned up by the SDK's SIGNED_OUT event —
            // so we keep the user logged in for anything short of a hard 404.
            let accountDeleted: Bool
            if case let .api(_, _, _, response) = error {
                accountDeleted = response.statusCode == 404
            } else {
                accountDeleted = error.errorCode == .userNotFound
            }
            if accountDeleted {
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
