import SwiftUI
import CoreData

struct ChatSplitView: View {
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
        NavigationView {
            List {
                ForEach(sessions) { session in
                    NavigationLink(destination: ChatView(session: session, viewModel: ChatViewModel(context: context, settings: settings))) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                            Text(session.lastMessageText.isEmpty ? "暂无消息" : session.lastMessageText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.sidebar)
            .navigationTitle("对话")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addSession) {
                        Image(systemName: "plus")
                    }
                }
            }

            VStack(spacing: 12) {
                Image(systemName: "message")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text("请选择一条对话")
                    .foregroundColor(.secondary)
            }
        }
        .navigationViewStyle(.columns)
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
