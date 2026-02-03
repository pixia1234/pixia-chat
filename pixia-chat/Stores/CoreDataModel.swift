import CoreData

enum CoreDataModel {
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "ChatSession"
        sessionEntity.managedObjectClassName = NSStringFromClass(ChatSession.self)

        let messageEntity = NSEntityDescription()
        messageEntity.name = "Message"
        messageEntity.managedObjectClassName = NSStringFromClass(Message.self)

        let sessionId = NSAttributeDescription()
        sessionId.name = "id"
        sessionId.attributeType = .UUIDAttributeType
        sessionId.isOptional = false

        let sessionTitle = NSAttributeDescription()
        sessionTitle.name = "title"
        sessionTitle.attributeType = .stringAttributeType
        sessionTitle.isOptional = false

        let sessionCreatedAt = NSAttributeDescription()
        sessionCreatedAt.name = "createdAt"
        sessionCreatedAt.attributeType = .dateAttributeType
        sessionCreatedAt.isOptional = false

        let sessionUpdatedAt = NSAttributeDescription()
        sessionUpdatedAt.name = "updatedAt"
        sessionUpdatedAt.attributeType = .dateAttributeType
        sessionUpdatedAt.isOptional = false

        let sessionPinned = NSAttributeDescription()
        sessionPinned.name = "isPinned"
        sessionPinned.attributeType = .booleanAttributeType
        sessionPinned.isOptional = false
        sessionPinned.defaultValue = false

        let messageId = NSAttributeDescription()
        messageId.name = "id"
        messageId.attributeType = .UUIDAttributeType
        messageId.isOptional = false

        let messageRole = NSAttributeDescription()
        messageRole.name = "role"
        messageRole.attributeType = .stringAttributeType
        messageRole.isOptional = false

        let messageContent = NSAttributeDescription()
        messageContent.name = "content"
        messageContent.attributeType = .stringAttributeType
        messageContent.isOptional = false

        let messageCreatedAt = NSAttributeDescription()
        messageCreatedAt.name = "createdAt"
        messageCreatedAt.attributeType = .dateAttributeType
        messageCreatedAt.isOptional = false

        let messagesRel = NSRelationshipDescription()
        messagesRel.name = "messages"
        messagesRel.destinationEntity = messageEntity
        messagesRel.minCount = 0
        messagesRel.maxCount = 0
        messagesRel.deleteRule = .cascadeDeleteRule
        messagesRel.isOptional = true

        let sessionRel = NSRelationshipDescription()
        sessionRel.name = "session"
        sessionRel.destinationEntity = sessionEntity
        sessionRel.minCount = 1
        sessionRel.maxCount = 1
        sessionRel.deleteRule = .nullifyDeleteRule
        sessionRel.isOptional = false

        messagesRel.inverseRelationship = sessionRel
        sessionRel.inverseRelationship = messagesRel

        sessionEntity.properties = [sessionId, sessionTitle, sessionCreatedAt, sessionUpdatedAt, sessionPinned, messagesRel]
        messageEntity.properties = [messageId, messageRole, messageContent, messageCreatedAt, sessionRel]

        model.entities = [sessionEntity, messageEntity]
        return model
    }
}
