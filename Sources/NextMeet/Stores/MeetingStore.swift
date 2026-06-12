import AppKit
import Foundation

@MainActor
protocol MeetingProviding {
    func upcomingMeetingLinksForToday() async throws -> [MeetingLink]
}

@MainActor
final class MeetingStore: ObservableObject {
    @Published private(set) var meetings: [MeetingLink] = []
    @Published private(set) var status: MeetingListStatus = .idle
    @Published private(set) var isRefreshing = false

    private let provider: any MeetingProviding

    init(provider: any MeetingProviding) {
        self.provider = provider

        Task {
            await refresh()
        }
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        status = .loading

        do {
            let fetchedMeetings = try await provider.upcomingMeetingLinksForToday()
            meetings = fetchedMeetings
            status = fetchedMeetings.isEmpty ? .empty : .ready
        } catch {
            meetings = []
            status = .failed(error.localizedDescription)
        }

        isRefreshing = false
    }

    func open(_ meeting: MeetingLink) {
        NSWorkspace.shared.open(meeting.url)
    }
}
