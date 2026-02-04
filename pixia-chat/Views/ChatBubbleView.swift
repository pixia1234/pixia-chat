import SwiftUI

struct ChatBubbleView: View {
    let role: String
    let text: String
    var isDraft: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser {
                avatarView
            }
            bubbleView
            if isUser {
                avatarView
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var isUser: Bool {
        role == ChatRole.user || role == ChatRole.system
    }

    private var isAssistant: Bool {
        role == ChatRole.assistant
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(isUser ? Color.accentColor.opacity(0.2) : Color.green.opacity(0.2))
                .frame(width: 24, height: 24)
            if isUser {
                Text("我")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
        }
    }

    private var bubbleView: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            if isAssistant && !isDraft {
                MarkdownView(text: text)
            } else {
                Text(text)
                    .foregroundColor(isUser ? .white : .primary)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(
            ChatBubbleShape(
                topLeft: isUser ? 18 : 8,
                topRight: isUser ? 8 : 18,
                bottomLeft: isUser ? 18 : 8,
                bottomRight: isUser ? 8 : 18
            )
            .fill(isUser ? Color.accentColor.opacity(0.9) : Color.gray.opacity(0.18))
        )
        .overlay(
            ChatBubbleShape(
                topLeft: isUser ? 18 : 8,
                topRight: isUser ? 8 : 18,
                bottomLeft: isUser ? 18 : 8,
                bottomRight: isUser ? 8 : 18
            )
            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .frame(maxWidth: 520, alignment: isUser ? .trailing : .leading)
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
