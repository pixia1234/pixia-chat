import Foundation

final class OpenAIChatCompletionsClient: LLMClient {
    private let baseURL: URL
    private let apiKey: String

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func send(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?, options: LLMRequestOptions) async throws -> LLMResponse {
        var request = makeRequest(path: "v1/chat/completions")
        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { Self.formatMessage($0) },
            "temperature": temperature
        ]
        if let maxTokens = maxTokens {
            body["max_tokens"] = maxTokens
        }
        if options.reasoningEffort != .off {
            body["reasoning"] = ["effort": options.reasoningEffort.rawValue]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let errorMessage = Self.extractErrorMessage(from: json) {
            throw NSError(domain: "HTTP", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        let choices = (json?["choices"] as? [[String: Any]]) ?? []
        let message = (choices.first?["message"] as? [String: Any]) ?? [:]
        let content = (message["content"] as? String) ?? ""
        let reasoning = (message["reasoning_content"] as? String) ?? (message["reasoning"] as? String)
        let usage = Self.extractUsage(from: json)
        return LLMResponse(content: content, reasoning: reasoning?.trimmingCharacters(in: .whitespacesAndNewlines), usage: usage)
    }

    func stream(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?, options: LLMRequestOptions) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = makeRequest(path: "v1/chat/completions")
                    var body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": messages.map { Self.formatMessage($0) },
                        "temperature": temperature
                    ]
                    if let maxTokens = maxTokens {
                        body["max_tokens"] = maxTokens
                    }
                    body["stream_options"] = ["include_usage": true]
                    if options.reasoningEffort != .off {
                        body["reasoning"] = ["effort": options.reasoningEffort.rawValue]
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        var data = Data()
                        for try await byte in bytes {
                            data.append(byte)
                        }
                        throw Self.makeError(statusCode: http.statusCode, data: data)
                    }

                    let parser = SSEParser()
                    for try await line in bytes.lines {
                        for event in parser.feed(line: line) {
                            if event == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            if let errorMessage = Self.extractErrorMessage(fromLine: event) {
                                continuation.finish(throwing: NSError(domain: "HTTP", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                                return
                            }
                            if let delta = Self.extractDelta(from: event) {
                                if let reasoning = delta.reasoning, !reasoning.isEmpty {
                                    continuation.yield(.reasoning(reasoning))
                                }
                                if let content = delta.content, !content.isEmpty {
                                    continuation.yield(.content(content))
                                }
                            }
                            if let usage = Self.extractUsage(fromLine: event) {
                                continuation.yield(.usage(usage))
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

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw makeError(statusCode: http.statusCode, data: data)
        }
    }

    private static func makeError(statusCode: Int, data: Data) -> Error {
        let message = parseErrorMessage(from: data) ?? "HTTP \(statusCode)"
        return NSError(domain: "HTTP", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let error = obj["error"] as? [String: Any] {
            if let message = error["message"] as? String {
                return message
            }
        }
        if let message = obj["message"] as? String {
            return message
        }
        return nil
    }

    private static func extractDelta(from jsonLine: String) -> (content: String?, reasoning: String?)? {
        guard let data = jsonLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any] else {
            return nil
        }
        let content = delta["content"] as? String
        let reasoning = (delta["reasoning_content"] as? String) ?? (delta["reasoning"] as? String)
        if content == nil && reasoning == nil {
            return nil
        }
        return (content, reasoning)
    }

    private static func extractUsage(from json: [String: Any]?) -> LLMUsage? {
        guard let usage = json?["usage"] as? [String: Any] else { return nil }
        return LLMUsage(
            promptTokens: usage["prompt_tokens"] as? Int,
            completionTokens: usage["completion_tokens"] as? Int,
            totalTokens: usage["total_tokens"] as? Int
        )
    }

    private static func extractUsage(fromLine jsonLine: String) -> LLMUsage? {
        guard let data = jsonLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return extractUsage(from: obj)
    }

    private static func extractErrorMessage(from json: [String: Any]?) -> String? {
        if let error = json?["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        if let message = json?["message"] as? String {
            return message
        }
        return nil
    }

    private static func extractErrorMessage(fromLine jsonLine: String) -> String? {
        guard let data = jsonLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return extractErrorMessage(from: obj)
    }

    private static func formatMessage(_ message: ChatMessage) -> [String: Any] {
        if message.images.isEmpty {
            return ["role": message.role, "content": message.content]
        }
        var parts: [[String: Any]] = []
        if !message.content.isEmpty {
            parts.append(["type": "text", "text": message.content])
        }
        for image in message.images {
            parts.append([
                "type": "image_url",
                "image_url": ["url": image.dataURL]
            ])
        }
        return ["role": message.role, "content": parts]
    }
}
