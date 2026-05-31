import Foundation
import Supabase

enum ProgressPhotoError: LocalizedError {
    case noUser
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .noUser:
            return String(localized: "progress_photo.error.no_user",
                          defaultValue: "Sign in to save progress photos.",
                          comment: "Progress photo: not signed in")
        case .uploadFailed:
            return String(localized: "progress_photo.error.upload_failed",
                          defaultValue: "Couldn't upload your photo. Try again.",
                          comment: "Progress photo: image upload failed")
        }
    }
}

/// Backs before/after progress photos. Pixels live in the private
/// `progress-photos` bucket under `<uid>/...`; rows in `progress_photos` carry
/// the path + optional weight snapshot. Display uses short-lived signed URLs.
@MainActor
final class ProgressPhotoService {
    static let shared = ProgressPhotoService()
    private init() {}

    private let bucket = "progress-photos"

    func list(limit: Int = 100) async throws -> [ProgressPhoto] {
        guard let userId = AuthService.shared.userId else { return [] }
        return try await SupabaseService.shared
            .from("progress_photos")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("taken_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Uploads the image then writes its metadata row. Returns the new row.
    @discardableResult
    func upload(imageData: Data, weightKg: Double?, notes: String?) async throws -> ProgressPhoto {
        guard let userId = AuthService.shared.userId else { throw ProgressPhotoError.noUser }

        let timestamp = Int(Date().timeIntervalSince1970)
        // Lowercase the uid to match the storage RLS path-ownership check, which
        // compares against auth.uid()::text (lowercase). See FoodScanService.
        let path = "\(userId.uuidString.lowercased())/\(timestamp).jpg"

        do {
            _ = try await SupabaseService.shared.storage
                .from(bucket)
                .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        } catch {
            throw ProgressPhotoError.uploadFailed
        }

        let id = UUID()
        let takenAt = Date()
        var payload: [String: AnyJSON] = [
            "id": .string(id.uuidString),
            "user_id": .string(userId.uuidString),
            "image_path": .string(path),
            "taken_at": .string(ISO8601DateFormatter().string(from: takenAt)),
        ]
        if let weightKg { payload["weight_kg"] = .double(weightKg) }
        if let notes, !notes.isEmpty { payload["notes"] = .string(notes) }

        try await SupabaseService.shared.from("progress_photos").insert(payload).execute()

        return ProgressPhoto(id: id, userId: userId, imagePath: path,
                             weightKg: weightKg, notes: notes, takenAt: takenAt)
    }

    /// Short-lived signed URL for displaying a private photo.
    func signedURL(for path: String, expiresIn: Int = 3600) async throws -> URL {
        try await SupabaseService.shared.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
    }

    /// Removes both the storage object and its metadata row.
    func delete(_ photo: ProgressPhoto) async throws {
        try? await SupabaseService.shared.storage.from(bucket).remove(paths: [photo.imagePath])
        try await SupabaseService.shared.from("progress_photos")
            .delete()
            .eq("id", value: photo.id.uuidString)
            .execute()
    }
}
