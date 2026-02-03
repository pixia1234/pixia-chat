import Foundation
import CoreData

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var assistantDraft: String = ""
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?

    private let context: NSManagedObjectContext
    private let settings: SettingsStore
    private var streamTask: Task<Void, Never>?

    init(context: NSManagedObjectContext, settings: SettingsStore) {
        self.context = context
        self.settings = settings
    }

    func send(session: ChatSession) {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        errorMessage = nil

        let store = ChatStore(context: context)
        store.addMessage(to: session, role: ChatRole.user, content: trimmed)

        let messages = session.messagesArray.map { ChatMessage(role: $0.role, content: $0.content) }

        guard let url = URL(string: settings.baseURL) else {
            errorMessage = "Invalid Base URL"
            return
        }
        let apiKey = settings.apiKey
        guard !apiKey.isEmpty else {
            errorMessage = "API Key is missing"
            return
        }

        let client: LLMClient
        switch settings.apiMode {
        case .chatCompletions:
            client = OpenAIChatCompletionsClient(baseURL: url, apiKey: apiKey)
        case .responses:
            client = OpenAIResponsesClient(baseURL: url, apiKey: apiKey)
        }

        let maxTokens = settings.maxTokens > 0 ? settings.maxTokens : nil
        let temperature = settings.temperature

        if settings.stream {
            assistantDraft = ""
            isStreaming = true
            streamTask?.cancel()
            streamTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await token in client.stream(messages: messages, model: settings.model, temperature: temperature, maxTokens: maxTokens) {
                        if Task.isCancelled { break }
                        self.assistantDraft += token
                    }
                    self.finishStreaming(session: session)
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.isStreaming = false
                    self.streamTask = nil
                }
            }
        } else {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let text = try await client.send(messages: messages, model: settings.model, temperature: temperature, maxTokens: maxTokens)
                    store.addMessage(to: session, role: ChatRole.assistant, content: text)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopStreaming(session: ChatSession) {
        streamTask?.cancel()
        finishStreaming(session: session)
    }

    private func finishStreaming(session: ChatSession) {
        guard isStreaming || !assistantDraft.isEmpty else { return }
        let store = ChatStore(context: context)
        let draft = assistantDraft
        assistantDraft = ""
        isStreaming = false
        streamTask = nil
        if !draft.isEmpty {
            store.addMessage(to: session, role: ChatRole.assistant, content: draft)
        }
    }
}
