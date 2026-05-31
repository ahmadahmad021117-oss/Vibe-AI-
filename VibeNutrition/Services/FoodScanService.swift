import Foundation
import Supabase

enum FoodScanError: LocalizedError {
    case noUser
    case uploadFailed
    case analysisFailed(String)
    /// Text-description estimate (analyze-food-text) failed server-side.
    case textAnalysisFailed(String)
    /// Active premium entitlement required. Free users land here even on
    /// their first tap — there's no free daily allowance anymore.
    case premiumRequired

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
        case .textAnalysisFailed(let detail):
            let template = String(
                localized: "food_text.error.analysis_failed",
                defaultValue: "Couldn't estimate that meal (%@). Try rewording it.",
                comment: "Text meal estimate: server analysis failed; %@ is a short server-supplied detail string"
            )
            return String(format: template, detail)
        case .premiumRequired:
            return String(localized: "food_scan.error.premium_required",
                          defaultValue: "AI scanning is a Premium feature. Start your free trial to continue.",
                          comment: "Food scan: blocked because the user has no active premium entitlement")
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

        // Premium gate. Server-side is authoritative; this just skips the
        // upload round-trip when we already know the user has no entitlement.
        try EntitlementService.shared.assertCanScan()

        let timestamp = Int(Date().timeIntervalSince1970)
        // Lowercase the UUID: Swift's UUID.uuidString is uppercase, but Supabase Storage RLS
        // policies (and the edge function's path-ownership check) compare against
        // auth.uid()::text which is lowercase. Without this, every upload INSERT is rejected
        // with "new row violates row-level security policy".
        let path = "\(userId.uuidString.lowercased())/\(timestamp).jpg"

        do {
            _ = try await SupabaseService.shared.storage
                .from("food-scans")
                .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
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
            if case .httpError(let status, let data) = err {
                // Server-side authoritative entitlement gate. The client
                // pre-check in EntitlementService.assertCanScan() can race a
                // just-expired trial, so this 402 is the real source of truth.
                if status == 402 {
                    throw FoodScanError.premiumRequired
                }
                if let body = try? JSONDecoder().decode(AnalyzeError.self, from: data) {
                    // `quota_exceeded` retained for backwards compat with users
                    // on a pre-Cal-AI-model server until the deploy lands.
                    if body.error == "premium_required" || body.error == "quota_exceeded" {
                        throw FoodScanError.premiumRequired
                    }
                    throw FoodScanError.analysisFailed(body.detail ?? body.error ?? "server error")
                }
            }
            throw FoodScanError.analysisFailed(err.localizedDescription)
        } catch {
            throw FoodScanError.analysisFailed(error.localizedDescription)
        }
    }

    /// Estimate macros from a free-text meal description (e.g. "4 eggs and a toast").
    /// Premium-gated, like `analyze(imageData:)`. Returns one item per detected food.
    func analyzeText(description: String) async throws -> AnalyzedFood {
        guard AuthService.shared.userId != nil else { throw FoodScanError.noUser }

        // Premium gate. Server-side is authoritative; this just avoids the
        // round-trip when we already know the user has no entitlement.
        try EntitlementService.shared.assertCanScan()

        struct AnalyzeTextRequest: Encodable { let description: String }
        struct AnalyzeError: Decodable { let error: String?; let detail: String? }

        do {
            let response: AnalyzedFood = try await SupabaseService.shared.functions
                .invoke("analyze-food-text",
                        options: FunctionInvokeOptions(body: AnalyzeTextRequest(description: description)))
            return response
        } catch let err as FunctionsError {
            if case .httpError(let status, let data) = err {
                // Server-side authoritative entitlement gate (see analyze()).
                if status == 402 {
                    throw FoodScanError.premiumRequired
                }
                if let body = try? JSONDecoder().decode(AnalyzeError.self, from: data) {
                    if body.error == "premium_required" || body.error == "quota_exceeded" {
                        throw FoodScanError.premiumRequired
                    }
                    throw FoodScanError.textAnalysisFailed(body.detail ?? body.error ?? "server error")
                }
            }
            throw FoodScanError.textAnalysisFailed(err.localizedDescription)
        } catch {
            throw FoodScanError.textAnalysisFailed(error.localizedDescription)
        }
    }
}
