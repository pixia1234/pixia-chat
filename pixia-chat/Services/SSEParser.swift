import Foundation

final class SSEParser {
    func feed(line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard trimmed.hasPrefix("data:") else { return [] }
        let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        return [payload]
    }
}
