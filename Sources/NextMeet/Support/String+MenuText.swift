import Foundation

extension String {
    func condensedWhitespace() -> String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func truncatedForMenu(maxLength: Int = 30) -> String {
        guard count > maxLength else {
            return self
        }

        guard maxLength > 3 else {
            return String(prefix(maxLength))
        }

        return String(prefix(maxLength - 3)) + "..."
    }
}
