import AppKit
import Foundation
import UserNotifications

final class MeetingReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    private static let notificationPrefix = "com.hasit.NextMeet.meeting-reminder."
    private static let scheduledHistoryKey = "meetingReminders.scheduledHistory"
    private static let categoryIdentifier = "NEXTMEET_MEETING_REMINDER"
    private static let joinActionIdentifier = "NEXTMEET_JOIN_MEETING"
    private static let meetingURLUserInfoKey = "meetingURL"

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
        super.init()

        center.delegate = self
        configureCategories()
    }

    func scheduleReminders(
        for meetings: [MeetingLink],
        leadTime: TimeInterval
    ) async -> ReminderPermissionStatus {
        let permissionStatus = await ensureAuthorization()
        guard permissionStatus == .allowed else {
            await cancelAllPendingReminders()
            return permissionStatus
        }

        let now = Date()
        pruneScheduledHistory(now: now)
        let pendingIdentifiers = Set(
            await pendingNotificationRequests()
                .map(\.identifier)
                .filter { identifier in
                    identifier.hasPrefix(Self.notificationPrefix)
                }
        )

        let upcomingMeetings = meetings.filter { meeting in
            meeting.startDate > now
        }
        let validIdentifiers = Set(upcomingMeetings.map { meeting in
            notificationIdentifier(for: meeting, leadTime: leadTime)
        })

        await cancelStalePendingReminders(validIdentifiers: validIdentifiers)

        for meeting in upcomingMeetings {
            let identifier = notificationIdentifier(for: meeting, leadTime: leadTime)

            if pendingIdentifiers.contains(identifier) {
                continue
            }

            let fireDate = meeting.startDate.addingTimeInterval(-leadTime)
            if hasAlreadyScheduledReminder(identifier), fireDate <= now {
                continue
            }

            let triggerInterval = max(1, fireDate.timeIntervalSince(now))
            let request = notificationRequest(
                identifier: identifier,
                meeting: meeting,
                leadTime: leadTime,
                triggerInterval: triggerInterval
            )

            do {
                try await add(request)
                rememberScheduledReminder(identifier, expiresAt: meeting.startDate.addingTimeInterval(60 * 60))
            } catch {
                // A failed scheduling attempt should not break meeting refreshes.
            }
        }

        return .allowed
    }

    func cancelAllPendingReminders(clearHistory: Bool = true) async {
        let pendingRequests = await pendingNotificationRequests()
        let identifiers = pendingRequests
            .map(\.identifier)
            .filter { identifier in
                identifier.hasPrefix(Self.notificationPrefix)
            }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        if clearHistory {
            defaults.removeObject(forKey: Self.scheduledHistoryKey)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let shouldOpenMeeting = actionIdentifier == UNNotificationDefaultActionIdentifier ||
            actionIdentifier == Self.joinActionIdentifier

        guard shouldOpenMeeting,
              let urlString = response.notification.request.content.userInfo[Self.meetingURLUserInfoKey] as? String,
              let url = URL(string: urlString) else {
            completionHandler()
            return
        }

        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
            completionHandler()
        }
    }

    private func configureCategories() {
        let joinAction = UNNotificationAction(
            identifier: Self.joinActionIdentifier,
            title: "Join",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [joinAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    private func ensureAuthorization() async -> ReminderPermissionStatus {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return .allowed
        case .notDetermined:
            let granted = await requestAuthorization()
            return granted ? .allowed : .denied
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private func notificationRequest(
        identifier: String,
        meeting: MeetingLink,
        leadTime: TimeInterval,
        triggerInterval: TimeInterval
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Meeting starts \(leadTimeTitle(leadTime))"
        content.body = meeting.title
        content.subtitle = MeetingFormatters.menuTime.string(from: meeting.startDate)
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.threadIdentifier = "NextMeetMeetingReminders"
        content.userInfo = [
            Self.meetingURLUserInfoKey: meeting.url.absoluteString
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: triggerInterval,
            repeats: false
        )

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func leadTimeTitle(_ leadTime: TimeInterval) -> String {
        let minutes = max(1, Int(leadTime / 60))
        return minutes == 1 ? "in 1 minute" : "in \(minutes) minutes"
    }

    private func cancelStalePendingReminders(validIdentifiers: Set<String>) async {
        let staleIdentifiers = await pendingNotificationRequests()
            .map(\.identifier)
            .filter { identifier in
                identifier.hasPrefix(Self.notificationPrefix) &&
                    !validIdentifiers.contains(identifier)
            }

        center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func notificationIdentifier(for meeting: MeetingLink, leadTime: TimeInterval) -> String {
        let value = [
            meeting.id,
            String(Int(meeting.startDate.timeIntervalSince1970)),
            String(Int(leadTime))
        ].joined(separator: "|")

        return Self.notificationPrefix + stableHash(value)
    }

    private func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }

        return String(hash, radix: 16)
    }

    private func scheduledHistory() -> [String: TimeInterval] {
        defaults.dictionary(forKey: Self.scheduledHistoryKey) as? [String: TimeInterval] ?? [:]
    }

    private func hasAlreadyScheduledReminder(_ identifier: String) -> Bool {
        scheduledHistory()[identifier] != nil
    }

    private func rememberScheduledReminder(_ identifier: String, expiresAt: Date) {
        var history = scheduledHistory()
        history[identifier] = expiresAt.timeIntervalSince1970
        defaults.set(history, forKey: Self.scheduledHistoryKey)
    }

    private func pruneScheduledHistory(now: Date) {
        let timestamp = now.timeIntervalSince1970
        let prunedHistory = scheduledHistory().filter { _, expiresAt in
            expiresAt > timestamp
        }

        defaults.set(prunedHistory, forKey: Self.scheduledHistoryKey)
    }
}
