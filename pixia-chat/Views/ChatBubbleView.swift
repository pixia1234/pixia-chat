import SwiftUI
import UIKit

struct ChatBubbleView: View {
    let role: String
    let text: String
    var reasoning: String? = nil
    var imageData: Data? = nil
    var isDraft: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isRightAligned {
                avatarView
            }
            bubbleView
            if isRightAligned {
                avatarView
            }
        }
        .frame(maxWidth: .infinity, alignment: isRightAligned ? .trailing : .leading)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var isUser: Bool {
        role == ChatRole.user
    }

    private var isAssistant: Bool {
        role == ChatRole.assistant
    }

    private var isSystem: Bool {
        role == ChatRole.system
    }

    private var isRightAligned: Bool {
        isUser || isSystem
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(avatarColor.opacity(0.2))
                .frame(width: 24, height: 24)
            avatarContent
        }
    }

    private var avatarColor: Color {
        if isUser { return .accentColor }
        if isSystem { return .yellow }
        return .green
    }

    @ViewBuilder
    private var avatarContent: some View {
        if isUser {
            Text("我")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentColor)
        } else if isSystem {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.yellow)
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.green)
        }
    }

    private var bubbleView: some View {
        VStack(alignment: isRightAligned ? .trailing : .leading, spacing: 8) {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if let reasoning, !reasoning.isEmpty {
                VStack(alignment: isRightAligned ? .trailing : .leading, spacing: 4) {
                    Text("思考")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(reasoning)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(isRightAligned ? .trailing : .leading)
                        .textSelection(.enabled)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if isAssistant && !isDraft {
                if requiresWebView(text) {
                    MarkdownView(text: text)
                } else {
                    Text(.init(text))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(isRightAligned ? .trailing : .leading)
                        .textSelection(.enabled)
                }
            } else {
                Text(text)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(isRightAligned ? .trailing : .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(
            ChatBubbleShape(
                topLeft: isRightAligned ? 18 : 8,
                topRight: isRightAligned ? 8 : 18,
                bottomLeft: isRightAligned ? 18 : 8,
                bottomRight: isRightAligned ? 8 : 18
            )
            .fill(bubbleColor)
        )
        .overlay(
            ChatBubbleShape(
                topLeft: isRightAligned ? 18 : 8,
                topRight: isRightAligned ? 8 : 18,
                bottomLeft: isRightAligned ? 18 : 8,
                bottomRight: isRightAligned ? 8 : 18
            )
            .stroke(bubbleBorderColor, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .frame(maxWidth: 520, alignment: isRightAligned ? .trailing : .leading)
    }

    private var bubbleColor: Color {
        if isUser { return Color.accentColor.opacity(0.9) }
        if isSystem { return Color.yellow.opacity(0.25) }
        return Color.gray.opacity(0.18)
    }

    private var bubbleBorderColor: Color {
        if isSystem { return Color.yellow.opacity(0.5) }
        return Color.black.opacity(0.06)
    }

    private var textColor: Color {
        if isUser { return .white }
        if isSystem { return .primary }
        return .primary
    }

    private func requiresWebView(_ text: String) -> Bool {
        if text.contains("```") { return true }
        if text.contains("```math") { return true }
        if text.contains("```latex") { return true }
        if text.contains("$$") || text.contains("\\(") || text.contains("\\[") || text.contains("\\begin{") { return true }
        if text.range(of: #"\$[^$\n]+\$"#, options: .regularExpression) != nil { return true }
        if text.contains("\n|") && text.contains("|") { return true }
        return false
    }
}

private struct ChatBubbleShape: Shape {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomLeft: CGFloat
    let bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
        let tl = min(min(topLeft, rect.width / 2), rect.height / 2)
        let tr = min(min(topRight, rect.width / 2), rect.height / 2)
        let bl = min(min(bottomLeft, rect.width / 2), rect.height / 2)
        let br = min(min(bottomRight, rect.width / 2), rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                    radius: tr,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                    radius: br,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                    radius: bl,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                    radius: tl,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}
