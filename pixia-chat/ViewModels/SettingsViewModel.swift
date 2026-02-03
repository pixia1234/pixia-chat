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
    }

    func clearKey() {
        apiKey = ""
    }
}
