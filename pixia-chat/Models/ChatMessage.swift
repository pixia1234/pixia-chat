import Foundation

struct ChatImage: Codable {
    let data: Data
    let mimeType: String

    var dataURL: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
    let images: [ChatImage]

    init(role: String, content: String, images: [ChatImage] = []) {
        self.role = role
        self.content = content
        self.images = images
    }
}

enum ChatRole {
    static let system = "system"
    static let user = "user"
    static let assistant = "assistant"
}
