import Foundation

enum APIMode: String, CaseIterable, Identifiable {
    case chatCompletions = "chat_completions"
    case responses = "responses"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chatCompletions: return "聊天补全 (Chat Completions)"
        case .responses: return "Responses (响应)"
        }
    }
}

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let baseURL = "base_url"
        static let apiMode = "api_mode"
        static let model = "model"
        static let temperature = "temperature"
        static let maxTokens = "max_tokens"
        static let stream = "stream"
        static let systemPrompt = "system_prompt"
        static let contextLimit = "context_limit"
        static let reasoningEffort = "reasoning_effort"
        static let showTokenUsage = "show_token_usage"
    }

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Keys.baseURL) }
    }
    @Published var apiMode: APIMode {
        didSet { UserDefaults.standard.set(apiMode.rawValue, forKey: Keys.apiMode) }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }
    @Published var temperature: Double {
        didSet { UserDefaults.standard.set(temperature, forKey: Keys.temperature) }
    }
    @Published var maxTokens: Int {
        didSet { UserDefaults.standard.set(maxTokens, forKey: Keys.maxTokens) }
    }
    @Published var stream: Bool {
        didSet { UserDefaults.standard.set(stream, forKey: Keys.stream) }
    }
    @Published var systemPrompt: String {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: Keys.systemPrompt) }
    }
    @Published var contextLimit: Int {
        didSet { UserDefaults.standard.set(contextLimit, forKey: Keys.contextLimit) }
    }
    @Published var reasoningEffort: ReasoningEffort {
        didSet { UserDefaults.standard.set(reasoningEffort.rawValue, forKey: Keys.reasoningEffort) }
    }
    @Published var showTokenUsage: Bool {
        didSet { UserDefaults.standard.set(showTokenUsage, forKey: Keys.showTokenUsage) }
    }

    @Published var apiKey: String {
        didSet {
            if apiKey.isEmpty {
                KeychainService.shared.delete("openai_api_key")
            } else {
                KeychainService.shared.set(apiKey, for: "openai_api_key")
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        baseURL = defaults.string(forKey: Keys.baseURL) ?? "https://api.openai.com"
        apiMode = APIMode(rawValue: defaults.string(forKey: Keys.apiMode) ?? "responses") ?? .responses
        model = defaults.string(forKey: Keys.model) ?? "gpt-5.2"
        temperature = defaults.object(forKey: Keys.temperature) as? Double ?? 0.7
        maxTokens = defaults.object(forKey: Keys.maxTokens) as? Int ?? 256000
        stream = defaults.object(forKey: Keys.stream) as? Bool ?? true
        systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? "you are a helpful assistant"
        contextLimit = defaults.object(forKey: Keys.contextLimit) as? Int ?? 6
        reasoningEffort = ReasoningEffort(rawValue: defaults.string(forKey: Keys.reasoningEffort) ?? "off") ?? .off
        showTokenUsage = defaults.object(forKey: Keys.showTokenUsage) as? Bool ?? false
        apiKey = KeychainService.shared.get("openai_api_key") ?? ""
    }
}
