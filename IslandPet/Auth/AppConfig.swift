import Foundation

/// Service identifiers, read from Info.plist. The values originate in `Config/AppConfig.xcconfig`
/// (the single place they are defined) and are injected at build time.
enum AppConfig {
    static let supabaseURL: URL = {
        let value = string("SupabaseURL")
        guard let url = URL(string: value) else { preconditionFailure("SupabaseURL is not a valid URL: \(value)") }
        return url
    }()

    static let supabasePublishableKey = string("SupabasePublishableKey")
    static let googleClientID = string("GIDClientID")
    static let googleServerClientID = string("GIDServerClientID")

    private static func string(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.hasPrefix("$(") else {
            preconditionFailure("\(key) is missing from Info.plist. Check Config/AppConfig.xcconfig and project.yml.")
        }
        return value
    }
}
