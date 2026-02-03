import SwiftUI

struct ChatBubbleView: View {
    let role: String
    let text: String

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 40)
            }
            Text(text)
                .padding(12)
                .background(isUser ? Color.accentColor.opacity(0.85) : Color.gray.opacity(0.2))
                .foregroundColor(isUser ? .white : .primary)
                .cornerRadius(14)
            if !isUser {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var isUser: Bool {
        role == ChatRole.user
    }
}
