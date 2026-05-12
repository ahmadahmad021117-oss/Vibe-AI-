import SwiftUI

@main
struct VibeNutritionApp: App {
    init() {
        // Touch shared singletons so Supabase + auth bootstrap eagerly.
        _ = SupabaseService.shared
        _ = AuthService.shared
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinator()
                .preferredColorScheme(.dark)
                .tint(Theme.Palette.accent)
        }
    }
}
