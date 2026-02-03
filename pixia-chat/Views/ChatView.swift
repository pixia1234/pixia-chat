import SwiftUI
import CoreData
import UIKit

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
        UITextView.appearance().backgroundColor = .clear
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

            HStack(alignment: .bottom, spacing: 8) {
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
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                )

                if viewModel.isStreaming {
                    Button("停止") {
                        viewModel.stopStreaming(session: session)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("发送") {
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
            Alert(title: Text("错误"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("确定")))
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
        } else if viewModel.isAwaitingResponse {
            withAnimation {
                proxy.scrollTo("typing", anchor: .bottom)
            }
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
