import Foundation

protocol LLMClient {
    func send(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?) async throws -> String
    func stream(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?) -> AsyncThrowingStream<String, Error>
}
