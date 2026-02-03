import CoreData

final class ChatListViewModel: ObservableObject {
    private let store: ChatStore

    init(context: NSManagedObjectContext) {
        self.store = ChatStore(context: context)
    }

    func createSession() -> ChatSession {
        store.createSession()
    }

    func deleteSession(_ session: ChatSession) {
        store.deleteSession(session)
    }
}
