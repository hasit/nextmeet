import AppKit
import Foundation

@MainActor
protocol MeetingProviding {
    func upcomingMeetingLinksForToday() async throws -> [MeetingLink]
}

@MainActor
final class MeetingStore {
    private static let minimumRefreshIndicatorDuration: TimeInterval = 0.45

    private(set) var meetings: [MeetingLink] = []
    private(set) var status: MeetingListStatus = .idle
    private(set) var isRefreshing = false

    var onChange: (() -> Void)?

    private let provider: any MeetingProviding
    private var observers: [UUID: () -> Void] = [:]

    init(provider: any MeetingProviding) {
        self.provider = provider
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        let refreshStartedAt = Date()
        isRefreshing = true
        status = .loading
        notify()
        await Task.yield()

        do {
            let fetchedMeetings = try await provider.upcomingMeetingLinksForToday()
            meetings = fetchedMeetings
            status = fetchedMeetings.isEmpty ? .empty : .ready
        } catch {
            meetings = []
            status = .failed(error.localizedDescription)
        }

        let remainingIndicatorTime = Self.minimumRefreshIndicatorDuration - Date().timeIntervalSince(refreshStartedAt)
        if remainingIndicatorTime > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remainingIndicatorTime * 1_000_000_000))
        }

        isRefreshing = false
        notify()
    }

    func open(_ meeting: MeetingLink) {
        NSWorkspace.shared.open(meeting.url)
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

    private func notify() {
        onChange?()
        observers.values.forEach { observer in
            observer()
        }
    }
}
