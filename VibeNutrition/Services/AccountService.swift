import Foundation
import Supabase

@MainActor
final class AccountService {
    static let shared = AccountService()
    private init() {}

    /// Deletes ALL user data + storage + auth row via edge function.
    /// On success, the auth listener fires and RootCoordinator will route to .auth.
    func deleteAccount() async throws {
        try await SupabaseService.shared.functions
            .invoke("delete-account", options: FunctionInvokeOptions(body: [:] as [String: String]))
        try? await PurchaseService.shared.logOut()
        try await AuthService.shared.signOut()
    }

    /// Builds a JSON dump of the user's data and returns the file URL for the share sheet.
    func exportData() async throws -> URL {
        guard AuthService.shared.userId != nil else {
            throw NSError(domain: "AccountService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        async let profileT = ProfileService.shared.fetchCurrent()
        async let goalT = GoalService.shared.fetchLatest()
        async let targetT = TargetService.shared.fetchLatest()
        async let logsT = FoodLogService.shared.fetchToday()
        async let weightsT = WeightLogService.shared.fetchRecent(days: 365)

        let profile = try await profileT
        let goal = try await goalT
        let target = try await targetT
        let logs = try await logsT
        let weights = try await weightsT

        struct Export: Codable {
            let exported_at: Date
            let profile: Profile?
            let goal: Goal?
            let target: NutritionTarget?
            let food_logs: [FoodLog]
            let weight_logs: [WeightLog]
        }

        let payload = Export(
            exported_at: Date(),
            profile: profile,
            goal: goal,
            target: target,
            food_logs: logs,
            weight_logs: weights
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vibe-export-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url)
        return url
    }
}
