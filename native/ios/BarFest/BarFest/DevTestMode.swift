import Foundation

/// Mirrors Cap `ENABLE_DEV_TEST_MODE_UI` — Test Mode toggle + Log + Games.
enum DevTestMode {
    /// Shown when running the Bar Fest Test bundle, or when Inf.plist opts in.
    static var isUIEnabled: Bool {
        let bundle = Bundle.main.bundleIdentifier ?? ""
        if bundle.contains(".test") { return true }
        if Bundle.main.object(forInfoDictionaryKey: "ENABLE_DEV_TEST_MODE_UI") as? Bool == true {
            return true
        }
        if let s = Bundle.main.object(forInfoDictionaryKey: "ENABLE_DEV_TEST_MODE_UI") as? String {
            return s == "1" || s.lowercased() == "true" || s.lowercased() == "yes"
        }
        return false
    }
}
