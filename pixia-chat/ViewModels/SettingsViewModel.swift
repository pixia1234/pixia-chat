import Foundation
import UIKit

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
    @Published var contextLimit: Int {
        didSet { store.contextLimit = contextLimit }
    }
    @Published var reasoningEffort: ReasoningEffort {
        didSet { store.reasoningEffort = reasoningEffort }
    }
    @Published var isTesting: Bool = false
    @Published var testStatus: String?
    @Published var imageTestStatus: String?
    @Published var reasoningTestStatus: String?

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
        self.contextLimit = store.contextLimit
        self.reasoningEffort = store.reasoningEffort
    }

    func clearKey() {
        apiKey = ""
    }

    func testConnection() {
        testStatus = nil
        imageTestStatus = nil
        reasoningTestStatus = nil

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
                    maxTokens: 16,
                    options: .default
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

    func testImageSupport() {
        imageTestStatus = nil
        guard !apiKey.isEmpty else {
            imageTestStatus = "API Key 为空"
            return
        }
        guard let url = URL(string: baseURL) else {
            imageTestStatus = "Base URL 无效"
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

            guard let imageData = Self.sampleImageData() else {
                await MainActor.run {
                    self.imageTestStatus = "图片数据无效"
                    self.isTesting = false
                    Haptics.light()
                }
                return
            }
            let image = ChatImage(data: imageData, mimeType: "image/jpeg")
            let message = ChatMessage(role: ChatRole.user, content: "这张图的主要颜色是什么？", images: [image])

            do {
                _ = try await client.send(
                    messages: [message],
                    model: model,
                    temperature: temperature,
                    maxTokens: 64,
                    options: .default
                )
                await MainActor.run {
                    self.imageTestStatus = "图片测试成功"
                    self.isTesting = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    self.imageTestStatus = "图片测试失败：\(error.localizedDescription)"
                    self.isTesting = false
                    Haptics.light()
                }
            }
        }
    }

    func testReasoningSupport() {
        reasoningTestStatus = nil
        guard !apiKey.isEmpty else {
            reasoningTestStatus = "API Key 为空"
            return
        }
        guard let url = URL(string: baseURL) else {
            reasoningTestStatus = "Base URL 无效"
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

            let message = ChatMessage(role: ChatRole.user, content: "请用推理回答：1+1=?")
            do {
                let response = try await client.send(
                    messages: [message],
                    model: model,
                    temperature: temperature,
                    maxTokens: 32,
                    options: LLMRequestOptions(reasoningEffort: .medium)
                )
                await MainActor.run {
                    if let reasoning = response.reasoning, !reasoning.isEmpty {
                        self.reasoningTestStatus = "推理测试成功"
                    } else {
                        self.reasoningTestStatus = "推理测试完成，但未返回思考内容"
                    }
                    self.isTesting = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    self.reasoningTestStatus = "推理测试失败：\(error.localizedDescription)"
                    self.isTesting = false
                    Haptics.light()
                }
            }
        }
    }

    private static func sampleImageData() -> Data? {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 12, y: 12, width: 40, height: 40))
        }
        return image.jpegData(compressionQuality: 0.9)
    }
}
