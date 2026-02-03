import SwiftUI
import CoreData

struct ChatListView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settings: SettingsStore

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatSession.updatedAt, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<ChatSession>

    private var viewModel: ChatListViewModel {
        ChatListViewModel(context: context)
    }

    var body: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink(destination: ChatView(session: session, viewModel: ChatViewModel(context: context, settings: settings))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(.headline)
                        Text(session.lastMessageText.isEmpty ? "No messages yet" : session.lastMessageText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .navigationTitle("pixia-chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: addSession) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func addSession() {
        _ = viewModel.createSession()
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { sessions[$0] }.forEach { session in
            viewModel.deleteSession(session)
        }
    }
}
