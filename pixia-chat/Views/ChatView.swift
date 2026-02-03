import SwiftUI
import CoreData
import UIKit

struct ChatView: View {
    @ObservedObject var session: ChatSession
    @StateObject private var viewModel: ChatViewModel

    @FetchRequest private var messages: FetchedResults<Message>
    @State private var sendPulse = false
    @State private var wasAwaiting = false
    @State private var isSessionDeleted = false
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(session: ChatSession, context: NSManagedObjectContext, settings: SettingsStore) {
        self._session = ObservedObject(wrappedValue: session)
        self._viewModel = StateObject(wrappedValue: ChatViewModel(context: context, settings: settings))
        _messages = FetchRequest<Message>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Message.createdAt, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
        UITextView.appearance().backgroundColor = .clear
    }

    var body: some View {
        Group {
            if isSessionDeleted || session.managedObjectContext == nil || session.isDeleted {
                DeletedSessionView()
            } else {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(messages, id: \.objectID) { message in
                                    ChatBubbleView(role: message.role, text: message.content)
                                        .id(message.objectID)
                                }
                                if !viewModel.assistantDraft.isEmpty {
                                    ChatBubbleView(role: ChatRole.assistant, text: viewModel.assistantDraft)
                                        .id("draft")
                                }
                                if viewModel.isAwaitingResponse && viewModel.assistantDraft.isEmpty {
                                    TypingBubbleView()
                                        .id("typing")
                                }
                            }
                        }
                        .onChange(of: messages.count) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: viewModel.assistantDraft) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: viewModel.isAwaitingResponse) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                    }

                    Divider()

                    VStack(spacing: 8) {
                        if viewModel.isAwaitingResponse || viewModel.isStreaming {
                            ThinkingBarView()
                        }

                        HStack(alignment: .bottom, spacing: 8) {
                            inputField
                                .scaleEffect(sendPulse ? 0.98 : 1.0)
                                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: sendPulse)

                            if viewModel.isStreaming {
                                Button("停止") {
                                    viewModel.stopStreaming(session: session)
                                    Haptics.light()
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("发送") {
                                    triggerSendPulse()
                                    viewModel.send(session: session)
                                    Haptics.light()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Alert(title: Text("错误"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("确定")))
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)) { note in
            guard let deleted = note.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> else { return }
            if deleted.contains(where: { $0.objectID == session.objectID }) {
                isSessionDeleted = true
                DebugLogger.log("session deleted in view id=\(session.objectID.uriRepresentation().absoluteString)")
                viewModel.cancelStreaming()
                dismiss()
            }
        }
        .onChange(of: viewModel.isAwaitingResponse) { isAwaiting in
            if wasAwaiting && !isAwaiting {
                Haptics.success()
            }
            wasAwaiting = isAwaiting
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(last.objectID, anchor: .bottom)
            }
        } else if !viewModel.assistantDraft.isEmpty {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo("draft", anchor: .bottom)
            }
        } else if viewModel.isAwaitingResponse {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo("typing", anchor: .bottom)
            }
        }
    }

    private var inputField: some View {
        Group {
            if #available(iOS 16.0, *) {
                TextField("输入消息...", text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...6)
                    .padding(12)
            } else {
                ZStack(alignment: .topLeading) {
                    if viewModel.inputText.isEmpty {
                        Text("输入消息...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    TextEditor(text: $viewModel.inputText)
                        .frame(minHeight: 36, maxHeight: 140)
                        .padding(8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func triggerSendPulse() {
        sendPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            sendPulse = false
        }
    }

    private var titleText: String {
        if isSessionDeleted || session.managedObjectContext == nil || session.isDeleted {
            return "对话已删除"
        }
        return session.title
    }
}

private struct TypingBubbleView: View {
    var body: some View {
        HStack {
            TypingIndicatorView()
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.gray.opacity(0.2))
                )
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

private struct ThinkingBarView: View {
    var body: some View {
        HStack(spacing: 8) {
            TypingIndicatorView()
            Text("AI 正在思考中...")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 6)
    }
}

private struct DeletedSessionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("该对话已被删除")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}
