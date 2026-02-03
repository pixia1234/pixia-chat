import CoreData

struct ChatStore {
    let context: NSManagedObjectContext

    @discardableResult
    func createSession(title: String? = nil) -> ChatSession {
        let session = ChatSession(context: context)
        session.id = UUID()
        session.title = title ?? "New Chat"
        session.createdAt = Date()
        session.updatedAt = Date()
        saveContext()
        return session
    }

    func deleteSession(_ session: ChatSession) {
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
        if session.title == "New Chat" && role == ChatRole.user {
            session.title = String(content.prefix(32))
        }
        saveContext()
        return message
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
