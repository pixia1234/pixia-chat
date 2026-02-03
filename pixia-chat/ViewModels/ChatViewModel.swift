import Foundation
import CoreData

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var assistantDraft: String = ""
    @Published var isStreaming: Bool = false
    @Published var isAwaitingResponse: Bool = false
    @Published var errorMessage: String?

    private let context: NSManagedObjectContext
    private let settings: SettingsStore
    private var streamTask: Task<Void, Never>?
    private var requestToken: Int = 0
    private var responseStartTime: Date?

    init(context: NSManagedObjectContext, settings: SettingsStore) {
        self.context = context
        self.settings = settings
    }

    func send(session: ChatSession) {
        guard isSessionValid(session) else { return }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        errorMessage = nil
        isAwaitingResponse = true
        requestToken += 1
        let token = requestToken
        responseStartTime = Date()
        DebugLogger.log("send start session=\(session.id.uuidString) token=\(token) stream=\(settings.stream)")

        let store = ChatStore(context: context)
        store.addMessage(to: session, role: ChatRole.user, content: trimmed)

        let messages = session.messagesArray.map { ChatMessage(role: $0.role, content: $0.content) }

        guard let url = URL(string: settings.baseURL) else {
            errorMessage = "Base URL 无效"
            DebugLogger.log("send failed: invalid baseURL")
            endAwaiting(token: token)
            return
        }
        let apiKey = settings.apiKey
        guard !apiKey.isEmpty else {
            errorMessage = "API Key 为空"
            DebugLogger.log("send failed: missing apiKey")
            endAwaiting(token: token)
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
                    self.finishStreaming(session: session, token: token)
                } catch {
                    DebugLogger.log("stream error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.isStreaming = false
                    self.endAwaiting(token: token)
                    self.streamTask = nil
                }
            }
        } else {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let text = try await client.send(messages: messages, model: settings.model, temperature: temperature, maxTokens: maxTokens)
                    if self.isSessionValid(session) {
                        store.addMessage(to: session, role: ChatRole.assistant, content: text)
                    }
                } catch {
                    DebugLogger.log("send error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
                self.endAwaiting(token: token)
            }
        }
    }

    func stopStreaming(session: ChatSession) {
        streamTask?.cancel()
        finishStreaming(session: session, token: requestToken)
    }

    func cancelStreaming() {
        DebugLogger.log("cancelStreaming")
        streamTask?.cancel()
        assistantDraft = ""
        isStreaming = false
        isAwaitingResponse = false
        streamTask = nil
    }

    private func finishStreaming(session: ChatSession, token: Int) {
        guard isStreaming || !assistantDraft.isEmpty else { return }
        let draft = assistantDraft
        assistantDraft = ""
        isStreaming = false
        endAwaiting(token: token)
        streamTask = nil
        if !draft.isEmpty, isSessionValid(session) {
            let store = ChatStore(context: context)
            store.addMessage(to: session, role: ChatRole.assistant, content: draft)
        }
        DebugLogger.log("finishStreaming token=\(token) chars=\(draft.count)")
    }

    private func isSessionValid(_ session: ChatSession) -> Bool {
        let valid = session.managedObjectContext != nil && !session.isDeleted
        if !valid {
            DebugLogger.log("session invalid id=\(session.id.uuidString) deleted=\(session.isDeleted)")
        }
        return valid
    }

    private func endAwaiting(token: Int) {
        guard token == requestToken else { return }
        let minDuration: TimeInterval = 0.6
        if let startedAt = responseStartTime {
            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < minDuration {
                let delay = minDuration - elapsed
                Task { [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    if self.requestToken == token {
                        self.isAwaitingResponse = false
                    }
                }
                responseStartTime = nil
                return
            }
        }
        isAwaitingResponse = false
        responseStartTime = nil
    }
}
