import Foundation

enum ReasoningEffort: String, CaseIterable, Identifiable {
    case off = "off"
    case low = "low"
    case medium = "medium"
    case high = "high"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "关闭"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

struct LLMRequestOptions {
    var reasoningEffort: ReasoningEffort

    static let `default` = LLMRequestOptions(reasoningEffort: .off)
}

enum LLMStreamEvent {
    case content(String)
    case reasoning(String)
    case usage(LLMUsage)
}

struct LLMUsage {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    var total: Int? {
        if let totalTokens { return totalTokens }
        if let promptTokens, let completionTokens { return promptTokens + completionTokens }
        return nil
    }
}

struct LLMResponse {
    let content: String
    let reasoning: String?
    let usage: LLMUsage?
}
