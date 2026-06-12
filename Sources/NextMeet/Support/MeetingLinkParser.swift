import Foundation

struct ParsedMeetingLink {
    let url: URL
    let service: MeetingService
}

final class MeetingLinkParser {
    private let detector: NSDataDetector
    private let customSchemeRegex: NSRegularExpression

    init() {
        detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        customSchemeRegex = try! NSRegularExpression(pattern: #"(?i)\b(?:zoommtg|zoomus|msteams)://[^\s<>\]\)]+"#)
    }

    func bestLink(in fields: [String]) -> ParsedMeetingLink? {
        var candidates: [(link: ParsedMeetingLink, order: Int)] = []
        var order = 0
        var seenURLs = Set<String>()

        for field in fields {
            let text = field.condensedWhitespace()
            let links = detectedLinks(in: text).sorted { left, right in
                left.location < right.location
            }

            for detectedLink in links {
                guard let url = cleanedURLString(detectedLink.urlString),
                      isSupportedMeetingURL(url) else {
                    continue
                }

                let key = url.absoluteString.lowercased()
                guard !seenURLs.contains(key) else {
                    continue
                }

                seenURLs.insert(key)
                candidates.append((ParsedMeetingLink(url: url, service: MeetingService.classify(url)), order))
                order += 1
            }
        }

        return candidates
            .sorted { left, right in
                if left.link.service.rawValue == right.link.service.rawValue {
                    return left.order < right.order
                }
                return left.link.service.rawValue < right.link.service.rawValue
            }
            .first?
            .link
    }

    private func isSupportedMeetingURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }

        return ["http", "https", "zoommtg", "zoomus", "msteams"].contains(scheme)
    }

    private func detectedLinks(in text: String) -> [(urlString: String, location: Int)] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let detectedURLs = detector.matches(in: text, options: [], range: range).compactMap { match -> (String, Int)? in
            guard let urlString = match.url?.absoluteString else {
                return nil
            }

            return (urlString, match.range.location)
        }

        let customSchemeURLs = customSchemeRegex.matches(in: text, options: [], range: range).compactMap { match -> (String, Int)? in
            guard let matchRange = Range(match.range, in: text) else {
                return nil
            }

            return (String(text[matchRange]), match.range.location)
        }

        return detectedURLs + customSchemeURLs
    }

    private func cleanedURLString(_ urlString: String) -> URL? {
        var text = urlString
        let trailingCharacters = CharacterSet(charactersIn: ".,;:!?)]}>\"'")

        while let scalar = text.unicodeScalars.last,
              trailingCharacters.contains(scalar) {
            text.removeLast()
        }

        return URL(string: text)
    }
}
