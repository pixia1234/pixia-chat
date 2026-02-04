import Foundation
import UIKit

struct ChatExportSession {
    let id: UUID
    let title: String
    let createdAt: Date
}

struct ChatExportMessage {
    let role: String
    let content: String
    let reasoning: String?
    let createdAt: Date
}

enum PDFExportError: Error {
    case failed(String)

    var message: String {
        switch self {
        case .failed(let text):
            return text
        }
    }
}

struct PDFExporter {
    static func export(session: ChatExportSession, messages: [ChatExportMessage]) -> Result<URL, PDFExportError> {
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

            if let reasoning = message.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
               !reasoning.isEmpty {
                blocks.append(NSAttributedString(string: "\n思考：\(reasoning)\n", attributes: [
                    .font: metaFont,
                    .foregroundColor: UIColor.secondaryLabel,
                    .paragraphStyle: paragraphStyle
                ]))
            }

            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let markdown = renderMarkdown(content, font: bodyFont, color: UIColor.label)
            let wrapped = NSMutableAttributedString(string: "\n")
            wrapped.append(markdown)
            wrapped.append(NSAttributedString(string: "\n"))
            blocks.append(wrapped)
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
            return .success(url)
        } catch {
            DebugLogger.log("pdf export error: \(error.localizedDescription)")
            return .failure(.failed("导出失败"))
        }
    }

    private static func renderMarkdown(_ text: String, font: UIFont, color: UIColor) -> NSAttributedString {
        guard !text.isEmpty else { return NSAttributedString(string: "") }
        if let attributed = try? NSAttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
        ) {
            let mutable = NSMutableAttributedString(attributedString: attributed)
            applyBaseAttributes(to: mutable, font: font, color: color)
            return mutable
        }
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ])
    }

    private static func applyBaseAttributes(to attributed: NSMutableAttributedString, font: UIFont, color: UIColor) {
        let fullRange = NSRange(location: 0, length: attributed.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        attributed.addAttribute(.foregroundColor, value: color, range: fullRange)

        let scale = font.pointSize / UIFont.systemFontSize
        attributed.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let current = value as? UIFont else {
                attributed.addAttribute(.font, value: font, range: range)
                return
            }
            let targetSize = max(8, current.pointSize * scale)
            let traits = current.fontDescriptor.symbolicTraits
            if traits.contains(.traitMonoSpace) {
                let weight: UIFont.Weight = traits.contains(.traitBold) ? .bold : .regular
                let mono = UIFont.monospacedSystemFont(ofSize: targetSize, weight: weight)
                attributed.addAttribute(.font, value: mono, range: range)
                return
            }
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                attributed.addAttribute(.font, value: UIFont(descriptor: descriptor, size: targetSize), range: range)
            } else {
                attributed.addAttribute(.font, value: font, range: range)
            }
        }
    }
}
