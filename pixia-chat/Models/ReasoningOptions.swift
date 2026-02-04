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
