import Foundation
import CoreData

extension ChatSession {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChatSession> {
        return NSFetchRequest<ChatSession>(entityName: "ChatSession")
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var isPinned: Bool
    @NSManaged public var messages: Set<Message>?
}

extension ChatSession: Identifiable {
    var messagesArray: [Message] {
        let set = messages ?? []
        return set.sorted { $0.createdAt < $1.createdAt }
    }

    var lastMessageText: String {
        messagesArray.last?.content ?? ""
    }
}
