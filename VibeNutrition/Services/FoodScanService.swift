import Foundation
import Supabase

enum FoodScanError: LocalizedError {
    case noUser
    case uploadFailed
    case analysisFailed(String)
    case scanLimitReached

    var errorDescription: String? {
        switch self {
        case .noUser:
            return String(localized: "food_scan.error.no_user",
                          defaultValue: "Sign in to scan food.",
                          comment: "Food scan: not signed in")
        case .uploadFailed:
            return String(localized: "food_scan.error.upload_failed",
                          defaultValue: "Couldn't upload your photo. Try again.",
                          comment: "Food scan: image upload failed")
        case .analysisFailed(let detail):
            let template = String(
                localized: "food_scan.error.analysis_failed",
                defaultValue: "Couldn't analyze the photo (%@).",
                comment: "Food scan: server analysis failed; %@ is a short server-supplied detail string"
            )
            return String(format: template, detail)
        case .scanLimitReached:
            return String(localized: "food_scan.error.limit_reached",
                          defaultValue: "Daily free scan limit reached. Upgrade for unlimited scans.",
                          comment: "Food scan: free-tier daily limit hit")
        }
    }
}

struct AnalyzedFood: Codable, Equatable {
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
