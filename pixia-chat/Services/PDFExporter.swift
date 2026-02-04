import Foundation
import UIKit

struct PDFExporter {
    static func export(session: ChatSession, messages: [Message]) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let margin: CGFloat = 32
        let contentWidth = pageRect.width - margin * 2

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let titleFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 12)
        let metaFont = UIFont.systemFont(ofSize: 10)

        let title = session.title
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let createdAt = dateFormatter.string(from: session.createdAt)

        var blocks: [NSAttributedString] = []
        blocks.append(NSAttributedString(string: title, attributes: [
            .font: titleFont,
            .paragraphStyle: paragraphStyle
        ]))
        blocks.append(NSAttributedString(string: "创建时间：\(createdAt)", attributes: [
            .font: metaFont,
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ]))

        for message in messages {
            let roleLabel: String
            switch message.role {
            case ChatRole.user:
                roleLabel = "用户"
            case ChatRole.assistant:
                roleLabel = "助手"
            case ChatRole.system:
                roleLabel = "系统"
            default:
                roleLabel = message.role
            }
            let timeText = dateFormatter.string(from: message.createdAt)
            let header = "\n\(roleLabel)  ·  \(timeText)"
            blocks.append(NSAttributedString(string: header, attributes: [
                .font: metaFont,
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ]))

            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            blocks.append(NSAttributedString(string: "\n\(content)\n", attributes: [
                .font: bodyFont,
                .paragraphStyle: paragraphStyle
            ]))
        }

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PixiaChat-\(session.id.uuidString).pdf")

        do {
            try renderer.writePDF(to: url, withActions: { context in
                var y = margin
                context.beginPage()

                for block in blocks {
                    let bounding = block.boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )

                    if y + bounding.height > pageRect.height - margin {
                        context.beginPage()
                        y = margin
                    }

                    block.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: bounding.height))
                    y += bounding.height + 6
                }
            })
            return url
        } catch {
            DebugLogger.log("pdf export error: \(error.localizedDescription)")
            return nil
        }
    }
}
