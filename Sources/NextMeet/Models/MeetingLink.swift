import Foundation

struct MeetingLink: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let url: URL
    let service: MeetingService

    var menuTitle: String {
        let time = MeetingFormatters.menuTime.string(from: startDate)
        let fallbackTitle = title.isEmpty ? service.displayName : title
        return "\(time) \(fallbackTitle)".condensedWhitespace()
    }

    var helpText: String {
        let time = MeetingFormatters.helpTime.string(from: startDate)
        let fallbackTitle = title.isEmpty ? service.displayName : title
        return "\(time) - \(fallbackTitle) - \(service.displayName)".condensedWhitespace()
    }
}

enum MeetingService: Int {
    case zoom = 0
    case googleMeet = 1
    case teams = 2
    case webex = 3
    case generic = 99

    var displayName: String {
        switch self {
        case .zoom:
            return "Zoom"
        case .googleMeet:
            return "Google Meet"
        case .teams:
            return "Microsoft Teams"
        case .webex:
            return "Webex"
        case .generic:
            return "Meeting Link"
        }
    }

    var menuLabel: String {
        switch self {
        case .zoom:
            return "Zoom"
        case .googleMeet:
            return "Meet"
        case .teams:
            return "Teams"
        case .webex:
            return "Webex"
        case .generic:
            return "Link"
        }
    }

    static func classify(_ url: URL) -> MeetingService {
        let host = (url.host ?? "").lowercased()
        let absolute = url.absoluteString.lowercased()

        if host.contains("zoom.us") || absolute.hasPrefix("zoommtg://") || absolute.hasPrefix("zoomus://") {
            return .zoom
        }

        if host == "meet.google.com" {
            return .googleMeet
        }

        if host.contains("teams.microsoft.com") || host.contains("teams.live.com") || absolute.hasPrefix("msteams://") {
            return .teams
        }

        if host.contains("webex.com") {
            return .webex
        }

        return .generic
    }
}
