import EventKit
import Foundation

@MainActor
final class EventKitMeetingProvider: MeetingProviding {
    private let parser = MeetingLinkParser()
    private var eventStore: EKEventStore?

    func upcomingMeetingLinksForToday() async throws -> [MeetingLink] {
        let eventStore = currentEventStore()
        try await ensureCalendarAccess(eventStore: eventStore)

        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let predicate = eventStore.predicateForEvents(withStart: startOfToday, end: startOfTomorrow, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { event in
                !event.isAllDay &&
                    event.endDate >= now &&
                    event.startDate < startOfTomorrow
            }
            .sorted { left, right in
                left.startDate < right.startDate
            }

        var meetings: [MeetingLink] = []
        var seenMeetingKeys = Set<String>()

        for event in events {
            guard let parsedLink = parser.bestLink(in: searchFields(for: event)) else {
                continue
            }

            let duplicateKey = meetingDuplicateKey(startDate: event.startDate, url: parsedLink.url)
            guard seenMeetingKeys.insert(duplicateKey).inserted else {
                continue
            }

            let title = (event.title ?? "Untitled Meeting").condensedWhitespace()
            let idParts = [
                event.eventIdentifier ?? "",
                String(event.startDate.timeIntervalSince1970),
                parsedLink.url.absoluteString
            ]

            meetings.append(
                MeetingLink(
                    id: idParts.joined(separator: "|"),
                    title: title,
                    startDate: event.startDate,
                    url: parsedLink.url,
                    service: parsedLink.service
                )
            )
        }

        return meetings
    }

    private func meetingDuplicateKey(startDate: Date, url: URL) -> String {
        let startMinute = Int((startDate.timeIntervalSince1970 / 60).rounded())
        return [
            String(startMinute),
            url.absoluteString.lowercased()
        ].joined(separator: "|")
    }

    private func currentEventStore() -> EKEventStore {
        if let eventStore {
            return eventStore
        }

        let eventStore = EKEventStore()
        self.eventStore = eventStore
        return eventStore
    }

    private func searchFields(for event: EKEvent) -> [String] {
        [
            event.url?.absoluteString,
            event.location,
            event.notes,
            event.title
        ].compactMap { $0 }
    }

    private func ensureCalendarAccess(eventStore: EKEventStore) async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            return
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToEvents()
            if granted {
                return
            }
            throw CalendarMeetingError.accessDenied
        case .restricted:
            throw CalendarMeetingError.accessRestricted
        case .denied, .writeOnly:
            throw CalendarMeetingError.accessDenied
        @unknown default:
            throw CalendarMeetingError.accessUnknown
        }
    }
}

enum CalendarMeetingError: LocalizedError {
    case accessDenied
    case accessRestricted
    case accessUnknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access denied"
        case .accessRestricted:
            return "Calendar access restricted"
        case .accessUnknown:
            return "Calendar access unavailable"
        }
    }
}
