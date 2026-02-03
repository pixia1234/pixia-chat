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

    @State private var selectedSessionID: NSManagedObjectID?

    private var viewModel: ChatListViewModel {
        ChatListViewModel(context: context)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSessionID) {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(.headline)
                        Text(session.lastMessageText.isEmpty ? "暂无消息" : session.lastMessageText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedSessionID = session.objectID }
                    .tag(session.objectID)
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
        } detail: {
            if let session = selectedSession {
                ChatView(session: session, viewModel: ChatViewModel(context: context, settings: settings))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "message")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("请选择一条对话")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            if selectedSessionID == nil, let first = sessions.first {
                selectedSessionID = first.objectID
            }
        }
    }

    private var selectedSession: ChatSession? {
        guard let selectedSessionID else { return nil }
        return try? context.existingObject(with: selectedSessionID) as? ChatSession
    }

    private func addSession() {
        let session = viewModel.createSession()
        selectedSessionID = session.objectID
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { sessions[$0] }.forEach { session in
            if session.objectID == selectedSessionID {
                selectedSessionID = nil
            }
            viewModel.deleteSession(session)
        }
    }
}
