import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    private let iconWidth: CGFloat = 20
    private let iconSpacing: CGFloat = 10
    @State private var debugStatus: String?
    private var contextOptions: [Int] {
        let base = [4, 6, 8, 12, 20, 0]
        if base.contains(viewModel.contextLimit) {
            return base
        }
        var values = base.filter { $0 != 0 }
        values.append(viewModel.contextLimit)
        values = Array(Set(values)).sorted()
        return values + [0]
    }

    var body: some View {
        Form {
            Section(header: Text("API 设置"), footer: Text("API Key 会安全存储在本机钥匙串中。")) {
                HStack(spacing: 10) {
                    icon("key.fill", color: .orange)
                    SecureField("API Key", text: $viewModel.apiKey)
                }

                HStack(spacing: 10) {
                    icon("link", color: .blue)
                    TextField("Base URL", text: $viewModel.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                HStack(spacing: 10) {
                    icon("switch.2", color: .purple)
                    Picker("接口模式", selection: $viewModel.apiMode) {
                        ForEach(APIMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 10) {
                    icon("trash", color: .red)
                    Button("清除 API Key") {
                        viewModel.clearKey()
                        Haptics.light()
                    }
                    .foregroundColor(.red)
                }

                Button(action: { viewModel.testConnection() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .foregroundColor(.green)
                        if viewModel.isTesting {
                            ProgressView()
                        }
                        Text("测试连接")
                    }
                }
                .disabled(viewModel.isTesting)

                if let status = viewModel.testStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(status.contains("成功") ? .green : .secondary)
                }

                Button(action: { viewModel.testImageSupport() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                        if viewModel.isTesting {
                            ProgressView()
                        }
                        Text("测试图片支持")
                    }
                }
                .disabled(viewModel.isTesting)

                if let status = viewModel.imageTestStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(status.contains("成功") ? .green : .secondary)
                }

                Button(action: { viewModel.testReasoningSupport() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        if viewModel.isTesting {
                            ProgressView()
                        }
                        Text("测试推理支持")
                    }
                }
                .disabled(viewModel.isTesting)

                if let status = viewModel.reasoningTestStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(status.contains("成功") ? .green : .secondary)
                }
            }

            Section(header: Text("参数调节")) {
                HStack(spacing: 10) {
                    icon("cpu", color: .teal)
                    TextField("默认模型", text: $viewModel.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                HStack(alignment: .top, spacing: 10) {
                    icon("quote.bubble", color: .mint)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Prompt")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if #available(iOS 16.0, *) {
                            TextField("you are a helpful assistant", text: $viewModel.systemPrompt, axis: .vertical)
                                .lineLimit(2...6)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            TextEditor(text: $viewModel.systemPrompt)
                                .frame(minHeight: 60, maxHeight: 140)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                }

                HStack(spacing: 10) {
                    icon("thermometer", color: .pink)
                    Text("温度")
                    Spacer()
                    Text(String(format: "%.2f", viewModel.temperature))
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.temperature, in: 0...1, step: 0.05)
                    .tint(.cyan)
                    .padding(.leading, iconWidth + iconSpacing)

                HStack(spacing: 10) {
                    icon("brain.head.profile", color: .purple)
                    Text("推理强度")
                    Spacer()
                    Picker("", selection: $viewModel.reasoningEffort) {
                        ForEach(ReasoningEffort.allCases) { effort in
                            Text(effort.title)
                                .tag(effort)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack(spacing: 10) {
                    icon("number", color: .indigo)
                    TextField("最大 Tokens", text: maxTokensTextBinding)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                }

                HStack(spacing: 10) {
                    icon("tray.full", color: .blue)
                    Text("上下文条数")
                    Spacer()
                    Picker("", selection: $viewModel.contextLimit) {
                        ForEach(contextOptions, id: \.self) { value in
                            Text(value == 0 ? "无限" : "\(value) 条")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack(spacing: 10) {
                    icon("sum", color: .green)
                    Toggle("显示 Token 消耗", isOn: $viewModel.showTokenUsage)
                }

                HStack(spacing: 10) {
                    icon("bolt.horizontal", color: .orange)
                    Toggle("流式输出", isOn: $viewModel.stream)
                }
            }

            Section(header: Text("调试")) {
                Button("复制日志") {
                    DebugLogger.copyToPasteboard()
                    Haptics.light()
                    showDebugStatus("已复制到剪贴板")
                }
                Button("清空日志") {
                    DebugLogger.clear()
                    Haptics.light()
                    showDebugStatus("日志已清空")
                }
                Text("日志文件：Documents/pixia-debug.log")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if let debugStatus {
                    Text(debugStatus)
                        .font(.footnote)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("设置")
    }

    private var maxTokensTextBinding: Binding<String> {
        Binding(
            get: {
                viewModel.maxTokens == 0 ? "" : String(viewModel.maxTokens)
            },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                if filtered.isEmpty {
                    viewModel.maxTokens = 0
                } else if let value = Int(filtered) {
                    viewModel.maxTokens = value
                }
            }
        )
    }

    private func icon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .foregroundColor(color)
            .frame(width: iconWidth, alignment: .center)
    }

    private func showDebugStatus(_ text: String) {
        debugStatus = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if debugStatus == text {
                debugStatus = nil
            }
        }
    }
}
