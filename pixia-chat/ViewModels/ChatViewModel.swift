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
    private var isGeneratingTitle: Bool = false

    init(context: NSManagedObjectContext, settings: SettingsStore) {
        self.context = context
        self.settings = settings
    }

    @discardableResult
    func send(session: ChatSession, image: ChatImage? = nil) -> Bool {
        guard isSessionValid(session) else { return false }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || image != nil else { return false }
        inputText = ""

        let store = ChatStore(context: context)
        let systemPrompt = settings.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if session.messagesArray.isEmpty, !systemPrompt.isEmpty {
            store.addMessage(to: session, role: ChatRole.system, content: systemPrompt)
        }
        store.addMessage(to: session, role: ChatRole.user, content: trimmed, imageData: image?.data, imageMimeType: image?.mimeType)

        let requestMessages = session.messagesArray.map { self.buildMessage(from: $0) }
        performRequest(session: session, requestMessages: requestMessages, label: "send")
        return true
    }

    func regenerate(session: ChatSession, from message: Message) {
        guard isSessionValid(session) else { return }
        guard message.role != ChatRole.system else { return }
        cancelStreaming()

        let messages = session.messagesArray
        guard let index = messages.firstIndex(where: { $0.objectID == message.objectID }) else { return }

        let keepCount = (message.role == ChatRole.assistant) ? index : min(index + 1, messages.count)
        let toDelete = Array(messages.dropFirst(keepCount))
        let store = ChatStore(context: context)
        store.deleteMessages(toDelete)

        let requestMessages = session.messagesArray
            .filter { $0.role != ChatRole.system }
            .map { self.buildMessage(from: $0) }
        guard let last = requestMessages.last, last.role == ChatRole.user else { return }
        performRequest(session: session, requestMessages: session.messagesArray.map { self.buildMessage(from: $0) }, label: "regenerate")
    }

    func updateMessage(_ message: Message, content: String) {
        let store = ChatStore(context: context)
        store.updateMessage(message, content: content)
    }

    func deleteMessage(_ message: Message) {
        cancelStreaming()
        let store = ChatStore(context: context)
        store.deleteMessage(message)
    }

    private func performRequest(session: ChatSession, requestMessages: [ChatMessage], label: String) {
        errorMessage = nil
        isAwaitingResponse = true
        requestToken += 1
        let token = requestToken
        responseStartTime = Date()
        DebugLogger.log("\(label) start session=\(session.objectID.uriRepresentation().absoluteString) token=\(token) stream=\(settings.stream)")

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
        let options = LLMRequestOptions(reasoningEffort: settings.reasoningEffort)
        let cappedMessages = applyContextLimit(requestMessages)

        if settings.stream {
            assistantDraft = ""
            isStreaming = true
            streamTask?.cancel()
            streamTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await token in client.stream(messages: cappedMessages, model: settings.model, temperature: temperature, maxTokens: maxTokens, options: options) {
                        if Task.isCancelled { break }
                        self.appendStreamText(token)
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
                    let text = try await client.send(messages: cappedMessages, model: settings.model, temperature: temperature, maxTokens: maxTokens, options: options)
                    if self.isSessionValid(session), !text.isEmpty {
                        let store = ChatStore(context: self.context)
                        store.addMessage(to: session, role: ChatRole.assistant, content: text)
                        self.maybeGenerateTitle(for: session)
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
    }

    private func finishStreaming(session: ChatSession, token: Int) {
        guard isStreaming || !assistantDraft.isEmpty else { return }
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
            maybeGenerateTitle(for: session)
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

    private func appendStreamText(_ text: String) {
        guard !text.isEmpty else { return }
        assistantDraft.append(contentsOf: text)
    }

    private func applyContextLimit(_ messages: [ChatMessage]) -> [ChatMessage] {
        let limit = settings.contextLimit
        guard limit > 0 else { return messages }
        let systemMessages = messages.filter { $0.role == ChatRole.system }
        let historyMessages = messages.filter { $0.role != ChatRole.system }
        if historyMessages.count <= limit {
            return systemMessages + historyMessages
        }
        return systemMessages + historyMessages.suffix(limit)
    }

    private func buildMessage(from message: Message) -> ChatMessage {
        var images: [ChatImage] = []
        if let data = message.imageData {
            let mimeType = message.imageMimeType ?? "image/jpeg"
            images = [ChatImage(data: data, mimeType: mimeType)]
        }
        return ChatMessage(role: message.role, content: message.content, images: images)
    }

    private func maybeGenerateTitle(for session: ChatSession) {
        guard !isGeneratingTitle else { return }
        guard isSessionValid(session) else { return }

        let firstUser = session.messagesArray.first(where: { $0.role == ChatRole.user })?.content ?? ""
        let preview = previewTitle(from: firstUser)
        let currentTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentTitle == "新的对话" || currentTitle == preview else { return }
        let allowedTitles = Set([currentTitle, "新的对话", preview])

        let messages = session.messagesArray.filter { $0.role != ChatRole.system }
        guard messages.contains(where: { $0.role == ChatRole.assistant }) else { return }

        guard let url = URL(string: settings.baseURL) else { return }
        let apiKey = settings.apiKey
        guard !apiKey.isEmpty else { return }

        isGeneratingTitle = true
        let client: LLMClient = {
            switch settings.apiMode {
            case .chatCompletions:
                return OpenAIChatCompletionsClient(baseURL: url, apiKey: apiKey)
            case .responses:
                return OpenAIResponsesClient(baseURL: url, apiKey: apiKey)
            }
        }()

        let summaryPrompt = buildSummaryPrompt(from: messages)
        Task { [weak self] in
            guard let self else { return }
            defer { self.isGeneratingTitle = false }
            do {
                let title = try await client.send(
                    messages: summaryPrompt,
                    model: self.settings.model,
                    temperature: 0.2,
                    maxTokens: 32,
                    options: .default
                )
                let cleaned = self.cleanTitle(title)
                guard !cleaned.isEmpty, self.isSessionValid(session) else { return }
                let latestTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard allowedTitles.contains(latestTitle) else { return }
                let store = ChatStore(context: self.context)
                store.renameSession(session, title: cleaned)
            } catch {
                DebugLogger.log("title summary error: \(error.localizedDescription)")
            }
        }
    }

    private func buildSummaryPrompt(from messages: [Message]) -> [ChatMessage] {
        let system = ChatMessage(
            role: ChatRole.system,
            content: "你是一个标题生成器。请根据对话内容生成简短标题（不超过16个字），只输出标题，不要引号或多余解释。"
        )
        let lines = messages.suffix(8).map { message -> String in
            let roleName = message.role == ChatRole.user ? "用户" : "助手"
            let compact = message.content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let clipped = compact.count > 200 ? String(compact.prefix(200)) + "..." : compact
            return "\(roleName): \(clipped)"
        }
        let user = ChatMessage(role: ChatRole.user, content: lines.joined(separator: "\n"))
        return [system, user]
    }

    private func previewTitle(from text: String) -> String {
        truncateTitle(text, limit: 18)
    }

    private func truncateTitle(_ text: String, limit: Int) -> String {
        let parts = text.split { $0.isWhitespace || $0.isNewline }
        var cleaned = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > limit {
            cleaned = String(cleaned.prefix(limit)) + "..."
        }
        return cleaned.isEmpty ? "新的对话" : cleaned
    }

    private func cleanTitle(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'"))
        if let firstLine = cleaned.components(separatedBy: .newlines).first {
            cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if cleaned.count > 18 {
            cleaned = String(cleaned.prefix(18)) + "..."
        }
        if cleaned.isEmpty {
            return ""
        }
        return cleaned
    }
}
