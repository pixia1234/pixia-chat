import SwiftUI
import WebKit

struct MarkdownView: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var height: CGFloat = 20

    var body: some View {
        MarkdownWebView(markdown: text, isDark: colorScheme == .dark, height: $height)
            .frame(height: max(20, height))
    }
}

private struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    let isDark: Bool
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(onHeightChange: { newHeight in
            if newHeight > 0 {
                height = newHeight
            }
        })
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "height")

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator

        let html = Self.htmlTemplate(isDark: isDark)
        webView.loadHTMLString(html, baseURL: nil)
        context.coordinator.pendingMarkdown = markdown
        context.coordinator.pendingIsDark = isDark
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingMarkdown = markdown
        context.coordinator.pendingIsDark = isDark
        if context.coordinator.isLoaded {
            context.coordinator.applyPending(to: webView)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var isLoaded = false
        var pendingMarkdown: String?
        var pendingIsDark: Bool?
        let onHeightChange: (CGFloat) -> Void

        init(onHeightChange: @escaping (CGFloat) -> Void) {
            self.onHeightChange = onHeightChange
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "height" else { return }
            if let value = message.body as? Double {
                onHeightChange(CGFloat(value))
            } else if let value = message.body as? Int {
                onHeightChange(CGFloat(value))
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            applyPending(to: webView)
        }

        func applyPending(to webView: WKWebView) {
            guard let markdown = pendingMarkdown else { return }
            let json = MarkdownWebView.jsonString(from: markdown)
            webView.evaluateJavaScript("window.updateMarkdown(\(json));")
            if let isDark = pendingIsDark {
                webView.evaluateJavaScript("window.setTheme(\(isDark ? "true" : "false"));")
            }
        }
    }

    private static func jsonString(from text: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [text])
        let json = String(data: data ?? Data("[\"\"]".utf8), encoding: .utf8) ?? "[\"\"]"
        let trimmed = String(json.dropFirst().dropLast())
        return trimmed.isEmpty ? "\"\"" : trimmed
    }

    private static func htmlTemplate(isDark: Bool) -> String {
        let katexCSS = loadResource(name: "katex.min", ext: "css")
        let markdownIt = loadResource(name: "markdown-it.min", ext: "js")
        let texmath = loadResource(name: "texmath.min", ext: "js")
        let katexJS = loadResource(name: "katex.min", ext: "js")
        let textColor = isDark ? "#F2F2F2" : "#1C1C1E"
        let codeBg = isDark ? "#1C1C1E" : "#F2F2F7"
        let border = isDark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)"
        let link = isDark ? "#7AB8FF" : "#2B7CFF"

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0"/>
          <style>
            \(katexCSS)
            :root {
              color-scheme: light dark;
            }
            body {
              margin: 0;
              padding: 0;
              font: -apple-system-body;
              color: \(textColor);
              background: transparent;
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
              background: var(--code-bg, \(codeBg));
              padding: 0.12em 0.28em;
              border-radius: 6px;
            }
            pre {
              background: var(--code-bg, \(codeBg));
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
              border: 1px solid var(--border-color, \(border));
              padding: 6px 8px;
              text-align: left;
            }
            a { color: var(--link-color, \(link)); }
          </style>
        </head>
        <body>
          <div id="content"></div>
          <script>\(katexJS)</script>
          <script>\(markdownIt)</script>
          <script>\(texmath)</script>
          <script>
            const md = window.markdownit({
              html: false,
              linkify: true,
              breaks: true
            }).use(texmath, { engine: katex, delimiters: ['dollars', 'brackets', 'beg_end', 'gitlab'] });

            function reportHeight() {
              const height = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.height) {
                window.webkit.messageHandlers.height.postMessage(height);
              }
            }

            window.setTheme = function(isDark) {
              const text = isDark ? "#F2F2F2" : "#1C1C1E";
              const code = isDark ? "#1C1C1E" : "#F2F2F7";
              const border = isDark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)";
              const link = isDark ? "#7AB8FF" : "#2B7CFF";
              document.body.style.color = text;
              const style = document.documentElement.style;
              style.setProperty("--code-bg", code);
              style.setProperty("--border-color", border);
              style.setProperty("--link-color", link);
            }

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

            window.updateMarkdown = function(text) {
              const prepared = preprocessMath(text);
              document.getElementById('content').innerHTML = md.render(prepared);
              setTimeout(reportHeight, 0);
            }

            window.addEventListener("load", reportHeight);
            window.addEventListener("resize", reportHeight);
          </script>
        </body>
        </html>
        """
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
