import Foundation

protocol LLMClient {
    func send(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?, options: LLMRequestOptions) async throws -> LLMResponse
    func stream(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?, options: LLMRequestOptions) -> AsyncThrowingStream<LLMStreamEvent, Error>
}
