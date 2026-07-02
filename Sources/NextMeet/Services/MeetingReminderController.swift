import EventKit
import Foundation

@MainActor
final class MeetingReminderController {
    private static let refreshInterval: UInt64 = 60_000_000_000
    private static let calendarChangeDebounce: UInt64 = 2_000_000_000

    private let store: MeetingStore
    private let preferencesStore: ReminderPreferencesStore
    private let scheduler: MeetingReminderScheduler

    private var refreshTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?
    private var calendarChangeTask: Task<Void, Never>?
    private var eventStoreObserver: NSObjectProtocol?
    private var isStarted = false

    init(
        store: MeetingStore,
        preferencesStore: ReminderPreferencesStore,
        scheduler: MeetingReminderScheduler
    ) {
        self.store = store
        self.preferencesStore = preferencesStore
        self.scheduler = scheduler
    }

    deinit {
        refreshTask?.cancel()
        scheduleTask?.cancel()
        calendarChangeTask?.cancel()

        if let eventStoreObserver {
            NotificationCenter.default.removeObserver(eventStoreObserver)
        }
    }

    func start() {
        guard !isStarted else {
            return
        }

        isStarted = true
        store.addObserver { [weak self] in
            self?.scheduleCurrentMeetings()
        }
        preferencesStore.addObserver { [weak self] in
            self?.preferencesChanged()
        }
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAfterCalendarChange()
            }
        }

        preferencesChanged()
    }

    private func preferencesChanged() {
        if preferencesStore.isEnabled {
            startRefreshLoop()
        } else {
            stopRefreshLoop()
            scheduleTask?.cancel()
            scheduleTask = Task { [scheduler] in
                await scheduler.cancelAllPendingReminders()
            }
        }
    }

    private func startRefreshLoop() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshIfEnabled()
                try? await Task.sleep(nanoseconds: Self.refreshInterval)
            }
        }
    }

    private func stopRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func refreshAfterCalendarChange() {
        guard preferencesStore.isEnabled else {
            return
        }

        calendarChangeTask?.cancel()
        calendarChangeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.calendarChangeDebounce)
            await self?.refreshIfEnabled()
        }
    }

    private func refreshIfEnabled() async {
        guard preferencesStore.isEnabled else {
            return
        }

        await store.refresh()
    }

    private func scheduleCurrentMeetings() {
        guard preferencesStore.isEnabled, !store.isRefreshing else {
            return
        }

        let meetings = store.meetings
        let leadTime = preferencesStore.leadTime

        scheduleTask?.cancel()
        scheduleTask = Task { [weak self, scheduler] in
            let permissionStatus = await scheduler.scheduleReminders(
                for: meetings,
                leadTime: leadTime
            )

            await MainActor.run {
                self?.preferencesStore.setPermissionStatus(permissionStatus)
            }
        }
    }
}
