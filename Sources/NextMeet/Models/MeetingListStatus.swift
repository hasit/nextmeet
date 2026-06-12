enum MeetingListStatus {
    case idle
    case loading
    case ready
    case empty
    case failed(String)

    var menuMessage: String {
        switch self {
        case .idle:
            return "Loading meetings..."
        case .loading:
            return "Refreshing..."
        case .ready:
            return "No meeting links today"
        case .empty:
            return "No meeting links today"
        case .failed(let message):
            return message.truncatedForMenu(maxLength: 30)
        }
    }
}
