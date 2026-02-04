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
    @State private var showEdit = false
    @State private var editDraft = ""
    @State private var editingMessageID: NSManagedObjectID?
    @State private var sharePayload: SharePayload?
    @State private var isUserDragging = false
    @State private var dragResetWorkItem: DispatchWorkItem?
    @State private var showImagePicker = false
    @State private var pendingImage: UIImage?
    @State private var pendingImageData: Data?
    @State private var pendingImageMimeType: String?
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var inputMinHeight: CGFloat { isPad ? 28 : 40 }
    private var inputMaxHeight: CGFloat { isPad ? 64 : 140 }

    init(session: ChatSession, context: NSManagedObjectContext, settings: SettingsStore) {
        self._session = ObservedObject(wrappedValue: session)
        self._viewModel = StateObject(wrappedValue: ChatViewModel(context: context, settings: settings))
        _messages = FetchRequest<Message>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Message.createdAt, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
        UITextView.appearance().backgroundColor = .clear
        UITextView.appearance().textContainerInset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
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
                                    ChatBubbleView(
                                        role: message.role,
                                        text: message.content,
                                        reasoning: message.reasoning,
                                        imageData: message.imageData,
                                        contextMenuContent: { AnyView(messageContextMenu(message)) }
                                    )
                                    .id(message.objectID)
                                }
                                if !viewModel.assistantDraft.isEmpty || !viewModel.assistantReasoningDraft.isEmpty {
                                    ChatBubbleView(role: ChatRole.assistant, text: viewModel.assistantDraft, reasoning: viewModel.assistantReasoningDraft, isDraft: true)
                                        .id("draft")
                                }
                                if viewModel.isAwaitingResponse && viewModel.assistantDraft.isEmpty && viewModel.assistantReasoningDraft.isEmpty {
                                    TypingBubbleView()
                                        .id("typing")
                                }
                            }
                        }
                        .modifier(KeyboardDismissOnScroll())
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                isUserDragging = true
                                dragResetWorkItem?.cancel()
                                let item = DispatchWorkItem {
                                    isUserDragging = false
                                }
                                dragResetWorkItem = item
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
                            }
                        )
                        .onChange(of: messages.count) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: viewModel.assistantDraft) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: viewModel.assistantReasoningDraft) { _ in
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

                        if let pendingImage {
                            HStack(alignment: .top) {
                                Image(uiImage: pendingImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Button {
                                    clearPendingImage()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 4)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }

                        HStack(alignment: .bottom, spacing: 8) {
                            Button {
                                showImagePicker = true
                            } label: {
                                Image(systemName: "photo")
                            }
                            .buttonStyle(.bordered)
                            .frame(height: inputMinHeight)
                            .disabled(viewModel.isStreaming)

                            inputField
                                .scaleEffect(sendPulse ? 0.98 : 1.0)
                                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: sendPulse)

                            if viewModel.isStreaming {
                                Button("停止") {
                                    viewModel.stopStreaming(session: session)
                                    Haptics.light()
                                }
                                .buttonStyle(.bordered)
                                .frame(height: inputMinHeight)
                            } else {
                                Button("发送") {
                                    triggerSendPulse()
                                    let imageData = pendingImageData ?? pendingImage?.jpegData(compressionQuality: 0.9)
                                    let attachment = imageData.map { ChatImage(data: $0, mimeType: pendingImageMimeType ?? "image/jpeg") }
                                    let didSend = viewModel.send(session: session, image: attachment)
                                    if didSend {
                                        clearPendingImage()
                                    }
                                    Haptics.light()
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(height: inputMinHeight)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    exportChat()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
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
        .sheet(isPresented: $showEdit) {
            NavigationView {
                VStack(spacing: 12) {
                    TextEditor(text: $editDraft)
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    Spacer()
                }
                .navigationTitle("编辑消息")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            showEdit = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            saveEdit()
                            showEdit = false
                        }
                    }
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                image: $pendingImage,
                imageData: $pendingImageData,
                mimeType: $pendingImageMimeType
            )
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if isUserDragging { return }
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(last.objectID, anchor: .bottom)
            }
        } else if !viewModel.assistantDraft.isEmpty || !viewModel.assistantReasoningDraft.isEmpty {
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
                let verticalPadding: CGFloat = isPad ? 6 : 10
                TextField("输入消息...", text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, verticalPadding)
                    .frame(minHeight: inputMinHeight, maxHeight: inputMaxHeight, alignment: .top)
            } else {
                ZStack(alignment: .topLeading) {
                    if viewModel.inputText.isEmpty {
                        Text("输入消息...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                    }
                    TextEditor(text: $viewModel.inputText)
                        .font(.body)
                        .frame(minHeight: inputMinHeight, maxHeight: inputMaxHeight)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
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

    private func clearPendingImage() {
        pendingImage = nil
        pendingImageData = nil
        pendingImageMimeType = nil
    }

    private var titleText: String {
        if isSessionDeleted || session.managedObjectContext == nil || session.isDeleted {
            return "对话已删除"
        }
        return session.title
    }

    private func messageContextMenu(_ message: Message) -> some View {
        Group {
            Button("复制") {
                let copied: String
                if let reasoning = message.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !reasoning.isEmpty {
                    copied = "思考：\n\(reasoning)\n\n内容：\n\(message.content)"
                } else {
                    copied = message.content
                }
                UIPasteboard.general.string = copied
                Haptics.light()
            }
            if message.role != ChatRole.system {
                Button("编辑") {
                    startEdit(message)
                }
                Button(role: .destructive) {
                    viewModel.deleteMessage(message)
                    Haptics.light()
                } label: {
                    Text("删除")
                }
                Button("重新生成") {
                    viewModel.regenerate(session: session, from: message)
                    Haptics.light()
                }
            }
        }
    }

    private func startEdit(_ message: Message) {
        editingMessageID = message.objectID
        editDraft = message.content
        showEdit = true
    }

    private func saveEdit() {
        guard let editingMessageID,
              let message = try? context.existingObject(with: editingMessageID) as? Message else {
            return
        }
        viewModel.updateMessage(message, content: editDraft)
    }

    private func exportChat() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let sessionSnapshot = ChatExportSession(id: session.id, title: session.title, createdAt: session.createdAt)
        let messageSnapshots = messages.map { message in
            ChatExportMessage(role: message.role, content: message.content, reasoning: message.reasoning, createdAt: message.createdAt)
        }
        Task.detached(priority: .userInitiated) {
            let result = PDFExporter.export(session: sessionSnapshot, messages: messageSnapshots)
            await MainActor.run {
                switch result {
                case .success(let url):
                    sharePayload = SharePayload(items: [url])
                    Haptics.light()
                case .failure(let error):
                    viewModel.errorMessage = error.message
                }
            }
        }
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct KeyboardDismissOnScroll: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.immediately)
        } else {
            content.simultaneousGesture(DragGesture().onChanged { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
        }
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
