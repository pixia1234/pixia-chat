import Foundation
import UIKit

enum DebugLogger {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static var logURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return (dir ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("pixia-debug.log")
    }

    static func log(_ message: String) {
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logURL, options: .atomic)
            }
        }
        #if DEBUG
        print(line.trimmingCharacters(in: .newlines))
        #endif
    }

    static func read() -> String {
        (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
    }

    static func clear() {
        try? FileManager.default.removeItem(at: logURL)
    }

    static func copyToPasteboard() {
        UIPasteboard.general.string = read()
    }
}
