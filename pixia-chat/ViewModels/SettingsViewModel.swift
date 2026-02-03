import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String {
        didSet { store.apiKey = apiKey }
    }
    @Published var baseURL: String {
        didSet { store.baseURL = baseURL }
    }
    @Published var apiMode: APIMode {
        didSet { store.apiMode = apiMode }
    }
    @Published var model: String {
        didSet { store.model = model }
    }
    @Published var temperature: Double {
        didSet { store.temperature = temperature }
    }
    @Published var maxTokens: Int {
        didSet { store.maxTokens = maxTokens }
    }
    @Published var stream: Bool {
        didSet { store.stream = stream }
    }
    @Published var systemPrompt: String {
        didSet { store.systemPrompt = systemPrompt }
    }
    @Published var isTesting: Bool = false
    @Published var testStatus: String?

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        self.apiKey = store.apiKey
        self.baseURL = store.baseURL
        self.apiMode = store.apiMode
        self.model = store.model
        self.temperature = store.temperature
        self.maxTokens = store.maxTokens
        self.stream = store.stream
        self.systemPrompt = store.systemPrompt
    }

    func clearKey() {
        apiKey = ""
    }

    func testConnection() {
        testStatus = nil

        guard !apiKey.isEmpty else {
            testStatus = "API Key 为空"
            return
        }
        guard let url = URL(string: baseURL) else {
            testStatus = "Base URL 无效"
            return
        }

        let apiKey = apiKey
        let model = model
        let apiMode = apiMode
        let temperature = temperature

        isTesting = true

        Task { [weak self] in
            guard let self else { return }
            let client: LLMClient = {
                switch apiMode {
                case .chatCompletions:
                    return OpenAIChatCompletionsClient(baseURL: url, apiKey: apiKey)
                case .responses:
                    return OpenAIResponsesClient(baseURL: url, apiKey: apiKey)
                }
            }()

            do {
                _ = try await client.send(
                    messages: [ChatMessage(role: ChatRole.user, content: "ping")],
                    model: model,
                    temperature: temperature,
                    maxTokens: 16
                )
                await MainActor.run {
                    self.testStatus = "连接成功"
                    self.isTesting = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    self.testStatus = "测试失败：\(error.localizedDescription)"
                    self.isTesting = false
                    Haptics.light()
                }
            }
        }
    }
}
