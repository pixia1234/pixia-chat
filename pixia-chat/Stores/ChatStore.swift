import Foundation
import CoreData

struct ChatStore {
    let context: NSManagedObjectContext

    @discardableResult
    func createSession(title: String? = nil) -> ChatSession {
        let session = ChatSession(context: context)
        session.id = UUID()
        session.title = title ?? "新的对话"
        session.createdAt = Date()
        session.updatedAt = Date()
        session.isPinned = false
        DebugLogger.log("createSession id=\(session.id.uuidString)")
        saveContext()
        return session
    }

    func deleteSession(_ session: ChatSession) {
        DebugLogger.log("deleteSession id=\(session.id.uuidString) deleted=\(session.isDeleted)")
        let messageIDs = session.messages?.map(\.id) ?? []
        for id in messageIDs {
            ChatImageStore.shared.removeImage(id: id)
        }
        context.delete(session)
        saveContext()
    }

    func deleteMessage(_ message: Message) {
        DebugLogger.log("deleteMessage id=\(message.id.uuidString) role=\(message.role)")
        ChatImageStore.shared.removeImage(id: message.id)
        context.delete(message)
        saveContext()
    }

    func deleteMessages(_ messages: [Message]) {
        guard !messages.isEmpty else { return }
        for message in messages {
            ChatImageStore.shared.removeImage(id: message.id)
            context.delete(message)
        }
        DebugLogger.log("deleteMessages count=\(messages.count)")
        saveContext()
    }

    func updateMessage(_ message: Message, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        message.content = trimmed
        message.session.updatedAt = Date()
        DebugLogger.log("updateMessage id=\(message.id.uuidString) role=\(message.role) chars=\(trimmed.count)")
        saveContext()
    }

    @discardableResult
    func addMessage(to session: ChatSession, role: String, content: String, reasoning: String? = nil, imageData: Data? = nil, imageMimeType: String? = nil) -> Message {
        let message = Message(context: context)
        message.id = UUID()
        message.role = role
        message.content = content
        message.imageData = imageData
        message.imageMimeType = imageMimeType
        message.reasoning = reasoning
        message.createdAt = Date()
        message.session = session
        if let imageData {
            ChatImageStore.shared.saveImage(data: imageData, id: message.id)
        }
        session.updatedAt = Date()
        if session.title == "新的对话" && role == ChatRole.user && !content.isEmpty {
            session.title = previewTitle(from: content)
        }
        DebugLogger.log("addMessage session=\(session.id.uuidString) role=\(role) chars=\(content.count)")
        saveContext()
        return message
    }

    func renameSession(_ session: ChatSession, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        session.title = trimmed
        session.updatedAt = Date()
        DebugLogger.log("renameSession id=\(session.id.uuidString) title=\(trimmed)")
        saveContext()
    }

    func togglePinned(_ session: ChatSession) {
        session.isPinned.toggle()
        session.updatedAt = Date()
        DebugLogger.log("togglePinned id=\(session.id.uuidString) pinned=\(session.isPinned)")
        saveContext()
    }

    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("CoreData save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func previewTitle(from text: String) -> String {
        return truncateTitle(text, limit: 18)
    }

    private func truncateTitle(_ text: String, limit: Int) -> String {
        let parts = text.split { $0.isWhitespace || $0.isNewline }
        var cleaned = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > limit {
            cleaned = String(cleaned.prefix(limit)) + "..."
        }
        return cleaned.isEmpty ? "新的对话" : cleaned
    }
}

final class ChatImageStore {
    static let shared = ChatImageStore()
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default

    private var directoryURL: URL? {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("ChatImages", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func saveImage(data: Data, id: UUID) {
        let key = id.uuidString as NSString
        cache.setObject(data as NSData, forKey: key)
        guard let url = fileURL(for: id) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    func loadImage(id: UUID) -> Data? {
        let key = id.uuidString as NSString
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }
        guard let url = fileURL(for: id), let data = try? Data(contentsOf: url) else { return nil }
        cache.setObject(data as NSData, forKey: key)
        return data
    }

    func removeImage(id: UUID) {
        let key = id.uuidString as NSString
        cache.removeObject(forKey: key)
        guard let url = fileURL(for: id) else { return }
        try? fileManager.removeItem(at: url)
    }

    private func fileURL(for id: UUID) -> URL? {
        directoryURL?.appendingPathComponent("\(id.uuidString).bin")
    }
}
