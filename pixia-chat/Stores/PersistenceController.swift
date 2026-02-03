import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        let session = ChatSession(context: viewContext)
        session.id = UUID()
        session.title = "Welcome"
        session.createdAt = Date()
        session.updatedAt = Date()

        let message = Message(context: viewContext)
        message.id = UUID()
        message.role = ChatRole.assistant
        message.content = "Hello from pixia-chat"
        message.createdAt = Date()
        message.session = session

        do {
            try viewContext.save()
        } catch {
            // Preview only; ignore errors
        }
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PixiaChat", managedObjectModel: CoreDataModel.makeModel())
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
