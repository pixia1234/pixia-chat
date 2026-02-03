import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 1
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        Form {
            Section(header: Text("API 设置"), footer: Text("API Key 会安全存储在本机钥匙串中。")) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                    SecureField("API Key", text: $viewModel.apiKey)
                }

                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                    TextField("Base URL", text: $viewModel.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                HStack(spacing: 10) {
                    Image(systemName: "switch.2")
                        .foregroundColor(.purple)
                    Picker("接口模式", selection: $viewModel.apiMode) {
                        ForEach(APIMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 10) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
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
            }

            Section(header: Text("参数调节")) {
                HStack(spacing: 10) {
                    Image(systemName: "cpu")
                        .foregroundColor(.teal)
                    TextField("默认模型", text: $viewModel.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                HStack {
                    Image(systemName: "thermometer")
                        .foregroundColor(.pink)
                    Text("温度")
                    Spacer()
                    Text(String(format: "%.2f", viewModel.temperature))
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.temperature, in: 0...1, step: 0.05)
                    .tint(.cyan)

                HStack(spacing: 10) {
                    Image(systemName: "number")
                        .foregroundColor(.indigo)
                    TextField("最大 Tokens", value: $viewModel.maxTokens, formatter: numberFormatter)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                }

                Toggle(isOn: $viewModel.stream) {
                    Label("流式输出", systemImage: "bolt.horizontal")
                }
            }

            Section(header: Text("调试")) {
                Button("复制日志") {
                    DebugLogger.copyToPasteboard()
                    Haptics.light()
                }
                Button("清空日志") {
                    DebugLogger.clear()
                    Haptics.light()
                }
                Text("日志文件：Documents/pixia-debug.log")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("设置")
    }
}
