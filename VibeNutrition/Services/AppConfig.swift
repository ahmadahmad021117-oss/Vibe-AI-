import Foundation

enum AppConfigError: Error { case missingKey(String) }

enum AppConfig {
    private static let plist: [String: Any] = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }()

    static func require(_ key: String) -> String {
        guard let value = plist[key] as? String, !value.isEmpty else {
            preconditionFailure("Missing Secrets.plist key: \(key)")
        }
        return value
    }

    static var supabaseURL: URL {
        guard let url = URL(string: require("SUPABASE_URL")) else {
            preconditionFailure("SUPABASE_URL is not a valid URL")
        }
        return url
    }

    static var supabaseAnonKey: String { require("SUPABASE_ANON_KEY") }
    static var revenueCatAPIKey: String { require("REVENUECAT_API_KEY") }
}
