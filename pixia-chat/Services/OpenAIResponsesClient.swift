import Foundation

final class OpenAIResponsesClient: LLMClient {
    private let baseURL: URL
    private let apiKey: String

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func send(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?) async throws -> String {
        var request = makeRequest(path: "v1/responses")
        var body: [String: Any] = [
            "model": model,
            "input": Self.formatInput(messages: messages),
            "temperature": temperature
        ]
        if let maxTokens = maxTokens {
            body["max_output_tokens"] = maxTokens
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let errorMessage = Self.extractErrorMessage(from: json) {
            throw NSError(domain: "HTTP", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        return Self.extractOutputText(from: json) ?? ""
    }

    func stream(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = makeRequest(path: "v1/responses")
                    var body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "input": Self.formatInput(messages: messages),
                        "temperature": temperature
                    ]
                    if let maxTokens = maxTokens {
                        body["max_output_tokens"] = maxTokens
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
                            if let delta = Self.extractOutputDelta(from: event) {
                                continuation.yield(delta)
                            }
                            if Self.isTerminalEvent(jsonLine: event) {
                                continuation.finish()
                                return
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

    private static func formatInput(messages: [ChatMessage]) -> [[String: Any]] {
        return messages.map { message in
            [
                "role": message.role,
                "content": [
                    ["type": "input_text", "text": message.content]
                ]
            ]
        }
    }

    private static func extractOutputText(from json: [String: Any]?) -> String? {
        if let outputText = json?["output_text"] as? String {
            return outputText
        }
        if let output = json?["output"] as? [[String: Any]] {
            var parts: [String] = []
            for item in output {
                if let content = item["content"] as? [[String: Any]] {
                    for contentItem in content {
                        if let text = contentItem["text"] as? String {
                            parts.append(text)
                        } else if let text = contentItem["output_text"] as? String {
                            parts.append(text)
                        }
                    }
                }
            }
            if !parts.isEmpty { return parts.joined() }
        }
        if let choices = json?["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        return nil
    }

    private static func extractOutputDelta(from jsonLine: String) -> String? {
        guard let data = jsonLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let type = obj["type"] as? String {
            switch type {
            case "response.output_text.delta":
                return obj["delta"] as? String
            case "response.output_text":
                return obj["text"] as? String
            case "response.output_text.done":
                return nil
            default:
                break
            }
        }
        if let delta = obj["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return text
        }
        if let text = obj["text"] as? String {
            return text
        }
        return nil
    }

    private static func isTerminalEvent(jsonLine: String) -> Bool {
        guard let data = jsonLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else {
            return false
        }
        return type == "response.completed" || type == "response.failed" || type == "response.canceled"
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
}
