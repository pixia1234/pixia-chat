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
            session.title = String(content.prefix(32))
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
}
