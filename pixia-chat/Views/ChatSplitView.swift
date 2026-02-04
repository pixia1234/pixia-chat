import SwiftUI
import CoreData

struct ChatSplitView: View {
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
    @State private var selectedSessionID: NSManagedObjectID?
    @State private var searchText: String = ""

    private var viewModel: ChatListViewModel {
        ChatListViewModel(context: context)
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationSplitView(columnVisibility: .constant(.all)) {
                    chatListiOS16
                } detail: {
                    if let session = selectedSession {
                        ChatView(session: session, context: context, settings: settings)
                            .id(session.objectID)
                    } else {
                        placeholderView
                    }
                }
            } else {
                NavigationView {
                    chatListiOS15
                    placeholderView
                }
                .navigationViewStyle(DoubleColumnNavigationViewStyle())
            }
        }
        .sheet(isPresented: $showRename) {
            renameSheet
        }
        .onAppear {
            if selectedSessionID == nil, let first = filteredSessions.first {
                selectedSessionID = first.objectID
            }
        }
        .onChange(of: searchText) { _ in
            if let selectedSessionID,
               filteredSessions.contains(where: { $0.objectID == selectedSessionID }) {
                return
            }
            selectedSessionID = filteredSessions.first?.objectID
        }
    }

    @available(iOS 16.0, *)
    private var chatListiOS16: some View {
        List(selection: $selectedSessionID) {
            ForEach(filteredSessions, id: \.objectID) { session in
                NavigationLink(value: session.objectID) {
                    VStack(alignment: .leading, spacing: 4) {
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
                }
                .tag(session.objectID)
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
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "搜索对话")
        .navigationTitle("对话")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: addSession) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var chatListiOS15: some View {
        List {
            ForEach(filteredSessions, id: \.objectID) { session in
                NavigationLink(destination: ChatView(session: session, context: context, settings: settings)) {
                    VStack(alignment: .leading, spacing: 4) {
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
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "搜索对话")
        .navigationTitle("对话")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: addSession) {
                    Image(systemName: "plus")
                }
            }
        }
    }


    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "message")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(sessions.isEmpty ? "开始你的第一条对话" : "请选择一条对话")
                .foregroundColor(.secondary)
        }
    }


    private var selectedSession: ChatSession? {
        guard let selectedSessionID else { return nil }
        return try? context.existingObject(with: selectedSessionID) as? ChatSession
    }

    private func addSession() {
        _ = viewModel.createSession()
        Haptics.light()
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { filteredSessions[$0] }.forEach { session in
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

    private var filteredSessions: [ChatSession] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Array(sessions) }
        return sessions.filter { matches(session: $0, query: query) }
    }

    private func matches(session: ChatSession, query: String) -> Bool {
        if session.title.localizedCaseInsensitiveContains(query) {
            return true
        }
        if session.lastMessageText.localizedCaseInsensitiveContains(query) {
            return true
        }
        for message in session.messagesArray {
            if message.content.localizedCaseInsensitiveContains(query) {
                return true
            }
        }
        return false
    }

    private var renameSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("给这条对话起个新名字")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("对话标题", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                Spacer()
            }
            .padding()
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showRename = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if let session = renamingSession {
                            viewModel.renameSession(session, title: renameText)
                            Haptics.light()
                        }
                        showRename = false
                    }
                }
            }
        }
    }
}
