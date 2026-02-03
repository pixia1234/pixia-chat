import Foundation
import CoreData

extension Message {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Message> {
        return NSFetchRequest<Message>(entityName: "Message")
    }

    @NSManaged public var id: UUID
    @NSManaged public var role: String
    @NSManaged public var content: String
    @NSManaged public var createdAt: Date
    @NSManaged public var session: ChatSession
}

extension Message: Identifiable {}
