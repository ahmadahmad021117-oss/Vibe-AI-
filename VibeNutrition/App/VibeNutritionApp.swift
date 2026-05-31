import SwiftUI

@main
struct VibeNutritionApp: App {
    @AppStorage(AppTheme.storageKey) private var appTheme: AppTheme = .system

    init() {
        // Touch shared singletons so Supabase + auth bootstrap eagerly.
        _ = SupabaseService.shared
        _ = AuthService.shared
        PurchaseService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinator()
                .preferredColorScheme(appTheme.colorScheme)
                .tint(Theme.Palette.accent)
        }
    }
}
