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

    func renameSession(_ session: ChatSession, title: String) {
        store.renameSession(session, title: title)
    }

    func togglePinned(_ session: ChatSession) {
        store.togglePinned(session)
    }
}
