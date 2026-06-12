import EventKit
import Foundation

@MainActor
final class EventKitMeetingProvider: MeetingProviding {
    private let eventStore = EKEventStore()
    private let parser = MeetingLinkParser()

    func upcomingMeetingLinksForToday() async throws -> [MeetingLink] {
        try await ensureCalendarAccess()

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

        for event in events {
            guard let parsedLink = parser.bestLink(in: searchFields(for: event)) else {
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

    private func searchFields(for event: EKEvent) -> [String] {
        [
            event.url?.absoluteString,
            event.location,
            event.notes,
            event.title
        ].compactMap { $0 }
    }

    private func ensureCalendarAccess() async throws {
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
