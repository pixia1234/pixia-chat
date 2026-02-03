import Foundation

struct ChatMessage: Codable {
    let role: String
    let content: String
}

enum ChatRole {
    static let system = "system"
    static let user = "user"
    static let assistant = "assistant"
}
