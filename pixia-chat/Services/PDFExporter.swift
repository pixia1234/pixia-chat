import Foundation
import UIKit
import WebKit

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
    let imageData: Data?
    let imageMimeType: String?
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
    static func export(session: ChatExportSession, messages: [ChatExportMessage]) async -> Result<URL, PDFExportError> {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let margin: CGFloat = 32

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PixiaChat-\(session.id.uuidString).pdf")

        let payloads = buildMessagePayloads(messages: messages, formatter: dateFormatter)
        let html = htmlTemplate(
            title: session.title,
            createdAt: dateFormatter.string(from: session.createdAt),
            messagesJSON: jsonString(from: payloads)
        )

        let coordinator = PDFWebViewCoordinator()
        let webView = await MainActor.run { () -> WKWebView in
            let controller = WKUserContentController()
            controller.add(coordinator, name: "ready")
            let config = WKWebViewConfiguration()
            config.userContentController = controller
            let view = WKWebView(frame: CGRect(x: 0, y: 0, width: pageRect.width, height: pageRect.height), configuration: config)
            view.isOpaque = false
            view.backgroundColor = .clear
            view.scrollView.isScrollEnabled = false
            view.navigationDelegate = coordinator
            return view
        }

        await MainActor.run {
            webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
        }

        let ready = await coordinator.waitReady()
        guard ready else {
            DebugLogger.log("pdf export error: webview not ready")
            return .failure(.failed("导出失败"))
        }

        let data = await createPDFData(from: webView, pageRect: pageRect, margin: margin)
        guard let data else {
            return .failure(.failed("导出失败"))
        }
        do {
            try data.write(to: url, options: [.atomic])
            return .success(url)
        } catch {
            DebugLogger.log("pdf export error: \(error.localizedDescription)")
            return .failure(.failed("导出失败"))
        }
    }

    private static func renderPDFData(from webView: WKWebView, pageRect: CGRect, margin: CGFloat) -> Data? {
        let formatter = webView.viewPrintFormatter()
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        let printableRect = pageRect.insetBy(dx: margin, dy: margin)
        renderer.setValue(pageRect, forKey: "paperRect")
        renderer.setValue(printableRect, forKey: "printableRect")

        renderer.prepare(forDrawingPages: NSRange(location: 0, length: 1))
        let pageCount = max(renderer.numberOfPages, 1)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = pdfRenderer.pdfData { context in
            for pageIndex in 0..<pageCount {
                context.beginPage()
                renderer.drawPage(at: pageIndex, in: printableRect)
            }
        }
        return data.isEmpty ? nil : data
    }

    private static func createPDFData(from webView: WKWebView, pageRect: CGRect, margin: CGFloat) async -> Data? {
        await MainActor.run {
            webView.frame = CGRect(origin: .zero, size: pageRect.size)
            webView.setNeedsLayout()
            webView.layoutIfNeeded()
        }
        await waitForLayout(webView)

        if #available(iOS 14.0, *) {
            let config = WKPDFConfiguration()
            config.rect = CGRect(origin: .zero, size: pageRect.size)
            let data: Data? = await withCheckedContinuation { continuation in
                webView.createPDF(configuration: config) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure:
                        continuation.resume(returning: nil)
                    }
                }
            }
            if let data, !data.isEmpty {
                return data
            }
        }
        return await MainActor.run { renderPDFData(from: webView, pageRect: pageRect, margin: margin) }
    }

    private static func waitForLayout(_ webView: WKWebView) async {
        for _ in 0..<6 {
            if let height = await evaluateJS(webView, script: "document.body && document.body.scrollHeight || 0") as? Double,
               height > 10 {
                break
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    private static func evaluateJS(_ webView: WKWebView, script: String) async -> Any? {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { result, _ in
                continuation.resume(returning: result)
            }
        }
    }

    private static func buildMessagePayloads(messages: [ChatExportMessage], formatter: DateFormatter) -> [[String: Any]] {
        return messages.map { message in
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
            var payload: [String: Any] = [
                "role": message.role,
                "roleLabel": roleLabel,
                "timeText": formatter.string(from: message.createdAt),
                "content": message.content
            ]
            if let reasoning = message.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
               !reasoning.isEmpty {
                payload["reasoning"] = reasoning
            }
            if let imageData = message.imageData, !imageData.isEmpty {
                payload["imageData"] = imageData.base64EncodedString()
                payload["imageMimeType"] = message.imageMimeType ?? "image/jpeg"
            }
            return payload
        }
    }

    private static func jsonString(from object: Any) -> String {
        let data = try? JSONSerialization.data(withJSONObject: object, options: [])
        var json = String(data: data ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        json = json.replacingOccurrences(of: "</", with: "<\\/")
        return json
    }

    private static func htmlTemplate(title: String, createdAt: String, messagesJSON: String) -> String {
        let katexCSS = loadResource(name: "katex.min", ext: "css")
        let markdownIt = loadResource(name: "markdown-it.min", ext: "js")
        let texmath = loadResource(name: "texmath.min", ext: "js")
        let katexJS = loadResource(name: "katex.min", ext: "js")

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
          <style>
            \(katexCSS)
            body {
              margin: 0;
              padding: 0;
              font: -apple-system-body;
              color: #1C1C1E;
              background: white;
            }
            .title {
              font-size: 20px;
              font-weight: 600;
              margin-bottom: 2px;
            }
            .meta {
              font-size: 10px;
              color: #6C6C70;
              margin-bottom: 12px;
            }
            .message {
              margin: 10px 0 14px;
              padding-bottom: 8px;
              border-bottom: 1px solid rgba(0,0,0,0.08);
            }
            .message:last-child {
              border-bottom: none;
            }
            .message-meta {
              font-size: 10px;
              color: #6C6C70;
              margin-bottom: 6px;
            }
            .reasoning {
              font-size: 11px;
              color: #6C6C70;
              background: #F2F2F7;
              padding: 6px 8px;
              border-radius: 8px;
              margin-bottom: 6px;
            }
            .reasoning-title {
              font-size: 10px;
              margin-bottom: 2px;
            }
            .attachment {
              max-width: 100%;
              height: auto;
              border-radius: 10px;
              margin-bottom: 6px;
            }
            h1, h2, h3, h4, h5, h6 {
              margin: 0.4em 0 0.2em;
            }
            p, ul, ol {
              margin: 0.2em 0 0.5em;
            }
            code {
              font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
              font-size: 0.92em;
              background: #F2F2F7;
              padding: 0.12em 0.28em;
              border-radius: 6px;
            }
            pre {
              background: #F2F2F7;
              padding: 0.6em 0.8em;
              border-radius: 10px;
              overflow-x: auto;
            }
            pre code {
              background: transparent;
              padding: 0;
            }
            table {
              width: 100%;
              border-collapse: collapse;
              margin: 0.4em 0;
              font-size: 0.95em;
            }
            th, td {
              border: 1px solid rgba(0,0,0,0.08);
              padding: 6px 8px;
              text-align: left;
            }
            a { color: #2B7CFF; }
          </style>
        </head>
        <body>
          <div class="title">\(escapeHTML(title))</div>
          <div class="meta">创建时间：\(escapeHTML(createdAt))</div>
          <div id="content"></div>
          <script>\(katexJS)</script>
          <script>\(markdownIt)</script>
          <script>\(texmath)</script>
          <script>
            const messages = \(messagesJSON);
            const md = window.markdownit({
              html: false,
              linkify: true,
              breaks: true
            }).use(texmath, { engine: katex, delimiters: ['dollars', 'brackets', 'beg_end', 'gitlab'] });

            function preprocessMath(text) {
              if (!text || text.indexOf("\\\\[") === -1) {
                return text;
              }
              const parts = text.split("```");
              for (let i = 0; i < parts.length; i += 2) {
                parts[i] = parts[i].replace(/\\\\\\[([\\s\\S]+?)\\\\\\]/g, function(_, inner) {
                  return "$$" + inner + "$$";
                });
              }
              return parts.join("```");
            }

            function renderMessage(msg) {
              let html = '<div class="message">';
              html += '<div class="message-meta">' + msg.roleLabel + ' · ' + msg.timeText + '</div>';
              if (msg.reasoning) {
                html += '<div class="reasoning">';
                html += '<div class="reasoning-title">思考</div>';
                html += '<div class="reasoning-body">' + md.render(preprocessMath(msg.reasoning)) + '</div>';
                html += '</div>';
              }
              if (msg.imageData) {
                const mime = msg.imageMimeType || 'image/jpeg';
                html += '<img class="attachment" src="data:' + mime + ';base64,' + msg.imageData + '" />';
              }
              html += '<div class="body">' + md.render(preprocessMath(msg.content || "")) + '</div>';
              html += '</div>';
              return html;
            }

            function renderAll() {
              const container = document.getElementById('content');
              container.innerHTML = messages.map(renderMessage).join('');
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ready) {
                window.webkit.messageHandlers.ready.postMessage('ready');
              }
            }
            window.addEventListener('load', renderAll);
          </script>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func loadResource(name: String, ext: String) -> String {
        let subdirs = ["Resources/markdown", "markdown", nil]
        for subdir in subdirs {
            let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdir)
            if let url, let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        return ""
    }
}

private final class PDFWebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var isReady = false

    func waitReady() async -> Bool {
        if isReady { return true }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ready" else { return }
        isReady = true
        continuation?.resume(returning: true)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(returning: false)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(returning: false)
        continuation = nil
    }
}
