import SwiftUI
import CoreData

struct ChatView: View {
    let session: ChatSession
    @ObservedObject var viewModel: ChatViewModel

    @FetchRequest private var messages: FetchedResults<Message>

    init(session: ChatSession, viewModel: ChatViewModel) {
        self.session = session
        self.viewModel = viewModel
        _messages = FetchRequest<Message>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Message.createdAt, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(messages) { message in
                            ChatBubbleView(role: message.role, text: message.content)
                                .id(message.id)
                        }
                        if !viewModel.assistantDraft.isEmpty {
                            ChatBubbleView(role: ChatRole.assistant, text: viewModel.assistantDraft)
                                .id("draft")
                        }
                    }
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.assistantDraft) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 36, maxHeight: 120)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                if viewModel.isStreaming {
                    Button("Stop") {
                        viewModel.stopStreaming(session: session)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Send") {
                        viewModel.send(session: session)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Alert(title: Text("Error"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else if !viewModel.assistantDraft.isEmpty {
            withAnimation {
                proxy.scrollTo("draft", anchor: .bottom)
            }
        }
    }
}
