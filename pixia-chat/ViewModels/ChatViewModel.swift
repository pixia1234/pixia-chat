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
    private var pendingCharacters: [Character] = []
    private var typingTask: Task<Void, Never>?
    private var streamDidEnd: Bool = false
    private var pendingFinishSession: ChatSession?
    private var pendingFinishToken: Int = 0

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
        DebugLogger.log("send start session=\(session.objectID.uriRepresentation().absoluteString) token=\(token) stream=\(settings.stream)")

        let store = ChatStore(context: context)
        let systemPrompt = settings.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if session.messagesArray.first?.role != ChatRole.system, !systemPrompt.isEmpty {
            store.addMessage(to: session, role: ChatRole.system, content: systemPrompt)
        }
        store.addMessage(to: session, role: ChatRole.user, content: trimmed)

        let requestMessages = session.messagesArray.map { ChatMessage(role: $0.role, content: $0.content) }

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
            streamDidEnd = false
            pendingFinishSession = nil
            pendingCharacters.removeAll()
            streamTask?.cancel()
            streamTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await token in client.stream(messages: requestMessages, model: settings.model, temperature: temperature, maxTokens: maxTokens) {
                        if Task.isCancelled { break }
                        self.enqueueTyping(token)
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
                    let text = try await client.send(messages: requestMessages, model: settings.model, temperature: temperature, maxTokens: maxTokens)
                    var simulated = false
                    if self.isSessionValid(session) {
                        simulated = self.startSimulatedTyping(text: text, session: session, token: token)
                    }
                } catch {
                    DebugLogger.log("send error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
                if !self.isStreaming {
                    self.endAwaiting(token: token)
                }
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
        pendingCharacters.removeAll()
        typingTask?.cancel()
        typingTask = nil
        streamDidEnd = false
        pendingFinishSession = nil
    }

    private func finishStreaming(session: ChatSession, token: Int) {
        guard isStreaming || !assistantDraft.isEmpty || !pendingCharacters.isEmpty else { return }
        streamDidEnd = true
        pendingFinishSession = session
        pendingFinishToken = token
        if typingTask != nil || !pendingCharacters.isEmpty {
            return
        }
        finalizeStreaming(session: session, token: token)
    }

    private func finalizeStreaming(session: ChatSession, token: Int) {
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
            DebugLogger.log("session invalid id=\(session.objectID.uriRepresentation().absoluteString) deleted=\(session.isDeleted)")
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

    private func enqueueTyping(_ text: String) {
        guard !text.isEmpty else { return }
        pendingCharacters.append(contentsOf: text)
        if typingTask == nil {
            startTypingTask()
        }
    }

    private func startTypingTask() {
        typingTask = Task { [weak self] in
            guard let self else { return }
            while !self.pendingCharacters.isEmpty {
                let ch = self.pendingCharacters.removeFirst()
                self.assistantDraft.append(ch)
                try? await Task.sleep(nanoseconds: 18_000_000)
            }
            self.typingTask = nil
            if self.streamDidEnd, let session = self.pendingFinishSession {
                let token = self.pendingFinishToken
                self.pendingFinishSession = nil
                self.streamDidEnd = false
                self.finalizeStreaming(session: session, token: token)
            }
        }
    }

    private func startSimulatedTyping(text: String, session: ChatSession, token: Int) -> Bool {
        guard !text.isEmpty else { return false }
        assistantDraft = ""
        isStreaming = true
        streamDidEnd = true
        pendingFinishSession = session
        pendingFinishToken = token
        pendingCharacters.removeAll()
        enqueueTyping(text)
        return true
    }
}
