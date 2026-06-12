import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginStore: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var helpText = "Open NextMeet automatically when you log in."

    init() {
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            helpText = "NextMeet opens automatically when you log in."
        case .notRegistered:
            try? LegacyLaunchAgent.repairIfNeeded()
            isEnabled = LegacyLaunchAgent.isInstalled
            helpText = isEnabled ? "NextMeet opens automatically when you log in." : "Open NextMeet automatically when you log in."
        case .requiresApproval:
            isEnabled = false
            helpText = "Approve NextMeet in System Settings > General > Login Items."
        case .notFound:
            try? LegacyLaunchAgent.repairIfNeeded()
            isEnabled = LegacyLaunchAgent.isInstalled
            helpText = "Uses a user LaunchAgent for this local build."
        @unknown default:
            try? LegacyLaunchAgent.repairIfNeeded()
            isEnabled = LegacyLaunchAgent.isInstalled
            helpText = "Uses a user LaunchAgent for this macOS version."
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if SMAppService.mainApp.status == .notFound {
                try LegacyLaunchAgent.setEnabled(enabled)
            } else {
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    try LegacyLaunchAgent.setEnabled(enabled)
                }
            }
        } catch {
            helpText = error.localizedDescription
        }

        refresh()
    }
}

private enum LegacyLaunchAgent {
    private static let label = "com.hasit.NextMeet.launch-at-login"
    private static let fileManager = FileManager.default
    private static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.hasit.NextMeet"

    static var isInstalled: Bool {
        fileManager.fileExists(atPath: plistURL.path)
    }

    static func repairIfNeeded() throws {
        guard isInstalled && needsRepair else {
            return
        }

        try install()
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try install()
        } else {
            try uninstall()
        }
    }

    private static func install() throws {
        try fileManager.createDirectory(
            at: launchAgentsDirectory,
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": label,
            "AssociatedBundleIdentifiers": [
                bundleIdentifier
            ],
            "ProgramArguments": [
                "/usr/bin/open",
                Bundle.main.bundleURL.path
            ],
            "RunAtLoad": true
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)

        _ = try? runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        try runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    private static func uninstall() throws {
        _ = try? runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])

        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
        }
    }

    private static var launchAgentsDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
    }

    private static var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist")
    }

    private static var needsRepair: Bool {
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return true
        }

        let expectedProgramArguments = [
            "/usr/bin/open",
            Bundle.main.bundleURL.path
        ]

        let programArguments = plist["ProgramArguments"] as? [String]
        let associatedBundleIdentifiers = plist["AssociatedBundleIdentifiers"] as? [String]

        return programArguments != expectedProgramArguments ||
            associatedBundleIdentifiers?.contains(bundleIdentifier) != true
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let error = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = errorText.condensedWhitespace().isEmpty ? outputText : errorText
            throw LaunchAtLoginError.launchctlFailed(message.condensedWhitespace())
        }

        return outputText
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchctlFailed(let message):
            return message.isEmpty ? "launchctl failed" : message
        }
    }
}
