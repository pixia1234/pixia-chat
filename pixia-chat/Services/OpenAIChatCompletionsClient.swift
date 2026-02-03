import Foundation

final class OpenAIChatCompletionsClient: LLMClient {
    private let baseURL: URL
    private let apiKey: String

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func send(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?) async throws -> String {
        var request = makeRequest(path: "v1/chat/completions")
        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature
        ]
        if let maxTokens = maxTokens {
            body["max_tokens"] = maxTokens
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = (json?["choices"] as? [[String: Any]]) ?? []
        let message = (choices.first?["message"] as? [String: Any]) ?? [:]
        return (message["content"] as? String) ?? ""
    }

    func stream(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = makeRequest(path: "v1/chat/completions")
                    var body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "temperature": temperature
                    ]
                    if let maxTokens = maxTokens {
                        body["max_tokens"] = maxTokens
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try Self.validate(response)

                    let parser = SSEParser()
                    for try await line in bytes.lines {
                        for event in parser.feed(line: line) {
                            if event == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            if let token = Self.extractDeltaToken(from: event) {
                                continuation.yield(token)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func makeRequest(path: String) -> URLRequest {
        let url = endpointURL(for: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func endpointURL(for path: String) -> URL {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if baseURL.path.hasSuffix("/v1"), cleanPath.hasPrefix("v1/") {
            let trimmed = String(cleanPath.dropFirst(3))
            return baseURL.appendingPathComponent(trimmed)
        }
        return baseURL.appendingPathComponent(cleanPath)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "HTTP", code: http.statusCode)
        }
    }

    private static func extractDeltaToken(from jsonLine: String) -> String? {
        guard let data = jsonLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let token = delta["content"] as? String else {
            return nil
        }
        return token
    }
}
