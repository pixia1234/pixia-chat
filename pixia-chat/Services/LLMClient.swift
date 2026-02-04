import Foundation

protocol LLMClient {
    func send(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?, options: LLMRequestOptions) async throws -> String
    func stream(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?, options: LLMRequestOptions) -> AsyncThrowingStream<String, Error>
}
