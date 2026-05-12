import Foundation
import Supabase

enum FoodScanError: LocalizedError {
    case noUser
    case uploadFailed
    case analysisFailed(String)
    case scanLimitReached

    var errorDescription: String? {
        switch self {
        case .noUser: return "Sign in to scan food."
        case .uploadFailed: return "Couldn't upload your photo. Try again."
        case .analysisFailed(let detail): return "Couldn't analyze the photo (\(detail))."
        case .scanLimitReached: return "Daily free scan limit reached. Upgrade for unlimited scans."
        }
    }
}

struct AnalyzedFood: Codable {
    let items: [FoodItem]

    var totals: (kcal: Int, protein: Double, carbs: Double, fat: Double) {
        items.reduce((0, 0.0, 0.0, 0.0)) { acc, item in
            (acc.0 + item.kcal, acc.1 + item.proteinG, acc.2 + item.carbsG, acc.3 + item.fatG)
        }
    }
}

@MainActor
final class FoodScanService {
    static let shared = FoodScanService()
    private init() {}

    /// Upload image, call analyze-food, return parsed result.
    func analyze(imageData: Data) async throws -> (path: String, food: AnalyzedFood) {
        guard let userId = AuthService.shared.userId else { throw FoodScanError.noUser }

        // Free-tier gate.
        try await EntitlementService.shared.assertCanScan()

        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "\(userId.uuidString)/\(timestamp).jpg"

        do {
            _ = try await SupabaseService.shared.storage
                .from("food-scans")
                .upload(path: path, file: imageData, options: FileOptions(contentType: "image/jpeg"))
        } catch {
            throw FoodScanError.uploadFailed
        }

        struct AnalyzeRequest: Encodable { let image_path: String }
        struct AnalyzeError: Decodable { let error: String?; let detail: String? }

        do {
            let response: AnalyzedFood = try await SupabaseService.shared.functions
                .invoke("analyze-food", options: FunctionInvokeOptions(body: AnalyzeRequest(image_path: path)))
            return (path, response)
        } catch let err as FunctionsError {
            if case .httpError(_, let data) = err,
               let body = try? JSONDecoder().decode(AnalyzeError.self, from: data) {
                throw FoodScanError.analysisFailed(body.detail ?? body.error ?? "server error")
            }
            throw FoodScanError.analysisFailed(err.localizedDescription)
        } catch {
            throw FoodScanError.analysisFailed(error.localizedDescription)
        }
    }
}
