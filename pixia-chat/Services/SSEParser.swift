import Foundation

final class SSEParser {
    private var buffer: [String] = []

    func feed(line: String) -> [String] {
        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defer { buffer.removeAll() }
            let datas = buffer.compactMap { line -> String? in
                guard line.hasPrefix("data:") else { return nil }
                return String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }
            return datas
        } else {
            buffer.append(line)
            return []
        }
    }
}
