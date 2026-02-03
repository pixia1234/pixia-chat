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
        context.delete(session)
        saveContext()
    }

    @discardableResult
    func addMessage(to session: ChatSession, role: String, content: String) -> Message {
        let message = Message(context: context)
        message.id = UUID()
        message.role = role
        message.content = content
        message.createdAt = Date()
        message.session = session
        session.updatedAt = Date()
        if session.title == "新的对话" && role == ChatRole.user {
            session.title = previewTitle(from: content)
        }
        if role == ChatRole.assistant {
            let firstUserContent = session.messagesArray.first(where: { $0.role == ChatRole.user })?.content ?? ""
            let preview = previewTitle(from: firstUserContent)
            if session.title == "新的对话" || session.title == preview {
                let summary = summaryTitle(from: session.messagesArray)
                if !summary.isEmpty {
                    session.title = summary
                }
            }
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

    private func summaryTitle(from messages: [Message]) -> String {
        let userTexts = messages.compactMap { $0.role == ChatRole.user ? $0.content : nil }
        guard let first = userTexts.first else { return "" }
        var base = first
        if base.count < 4, userTexts.count > 1 {
            base = base + " " + userTexts[1]
        }
        base = firstClause(from: base)
        return truncateTitle(base, limit: 18)
    }

    private func firstClause(from text: String) -> String {
        let separators = CharacterSet(charactersIn: "\n。！？.!?")
        if let range = text.rangeOfCharacter(from: separators) {
            return String(text[..<range.lowerBound])
        }
        return text
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
