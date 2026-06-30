import Foundation

struct AppMetadata {
    let version: String
    let build: String
    let commit: String

    var shortCommit: String {
        guard !commit.isEmpty else {
            return "Unknown"
        }

        return String(commit.prefix(8))
    }

    static let current = AppMetadata(bundle: .main)

    init(bundle: Bundle) {
        version = bundle.stringValue(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "Unknown"
        build = bundle.stringValue(forInfoDictionaryKey: "CFBundleVersion") ?? "Unknown"
        commit = bundle.stringValue(forInfoDictionaryKey: "NextMeetCommit") ?? ""
    }
}

private extension Bundle {
    func stringValue(forInfoDictionaryKey key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String,
              value.isEmpty == false else {
            return nil
        }

        return value
    }
}
