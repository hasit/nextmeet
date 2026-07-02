import Foundation

enum ReminderPermissionStatus {
    case unknown
    case allowed
    case denied
}

@MainActor
final class ReminderPreferencesStore {
    private static let isEnabledKey = "meetingReminders.isEnabled"
    private nonisolated static let defaultLeadTime: TimeInterval = 120

    private let defaults: UserDefaults
    private var observers: [UUID: () -> Void] = [:]

    private(set) var isEnabled: Bool
    private(set) var permissionStatus: ReminderPermissionStatus = .unknown
    let leadTime: TimeInterval

    init(
        defaults: UserDefaults = .standard,
        leadTime: TimeInterval = ReminderPreferencesStore.defaultLeadTime
    ) {
        self.defaults = defaults
        self.leadTime = leadTime
        isEnabled = defaults.bool(forKey: Self.isEnabledKey)
    }

    var menuAccessory: String {
        guard isEnabled else {
            return "Off"
        }

        switch permissionStatus {
        case .unknown, .allowed:
            return "On"
        case .denied:
            return "Denied"
        }
    }

    var helpText: String {
        guard isEnabled else {
            return "Send a macOS notification before each upcoming meeting."
        }

        switch permissionStatus {
        case .unknown, .allowed:
            return "NextMeet alerts you \(leadTimeHelpText) before meetings."
        case .denied:
            return "Allow NextMeet notifications in System Settings > Notifications."
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else {
            return
        }

        isEnabled = enabled
        defaults.set(enabled, forKey: Self.isEnabledKey)

        if !enabled {
            permissionStatus = .unknown
        }

        notify()
    }

    func setPermissionStatus(_ status: ReminderPermissionStatus) {
        guard permissionStatus != status else {
            return
        }

        permissionStatus = status
        notify()
    }

    @discardableResult
    func addObserver(_ observer: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    func removeObserver(id: UUID) {
        observers.removeValue(forKey: id)
    }

    private var leadTimeHelpText: String {
        let minutes = max(1, Int(leadTime / 60))
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private func notify() {
        observers.values.forEach { observer in
            observer()
        }
    }
}
