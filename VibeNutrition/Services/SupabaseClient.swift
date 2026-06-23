import Foundation
import Supabase

enum SupabaseService {
    static let shared: SupabaseClient = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                // Default Keychain storage (kSecAttrAccessibleAfterFirstUnlock) —
                // the session survives app relaunches and device reboots.
                storage: AuthClient.Configuration.defaultLocalStorage,
                // Refresh the access token automatically before it expires so the
                // user never gets bounced to the login screen mid-use.
                autoRefreshToken: true,
                // Surface the stored session immediately on launch instead of
                // waiting for a network refresh to succeed first. This keeps the
                // user logged in on cold/offline relaunches — the SDK refreshes
                // the token in the background once it's online again.
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
