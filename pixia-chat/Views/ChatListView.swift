import SwiftUI
import CoreData

struct ChatListView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settings: SettingsStore

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ChatSession.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ChatSession.updatedAt, ascending: false)
        ],
        animation: .default
    )
    private var sessions: FetchedResults<ChatSession>

    @State private var showRename = false
    @State private var renamingSession: ChatSession?
    @State private var renameText: String = ""

    private var viewModel: ChatListViewModel {
        ChatListViewModel(context: context)
    }

    var body: some View {
        ZStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink(destination: ChatView(session: session, viewModel: ChatViewModel(context: context, settings: settings))) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(session.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                if session.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                Spacer()
                                Text(relativeTime(from: session.updatedAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(session.lastMessageText.isEmpty ? "暂无消息" : session.lastMessageText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(session.isPinned ? "取消置顶" : "置顶") {
                            viewModel.togglePinned(session)
                            Haptics.light()
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("重命名") {
                            startRename(session)
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            delete(session: session)
                        } label: {
                            Text("删除")
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)

            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("开始你的第一条对话")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Pixia Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: addSession) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("重命名", isPresented: $showRename) {
            TextField("对话标题", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("保存") {
                if let session = renamingSession {
                    viewModel.renameSession(session, title: renameText)
                    Haptics.light()
                }
            }
        } message: {
            Text("给这条对话起个新名字")
        }
    }

    private func addSession() {
        _ = viewModel.createSession()
        Haptics.light()
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { sessions[$0] }.forEach { session in
            viewModel.deleteSession(session)
        }
    }

    private func delete(session: ChatSession) {
        viewModel.deleteSession(session)
    }

    private func startRename(_ session: ChatSession) {
        renamingSession = session
        renameText = session.title
        showRename = true
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
