import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section(header: Text("API"), footer: Text("API Key 会安全存储在本机钥匙串中。")) {
                SecureField("API Key", text: $viewModel.apiKey)
                TextField("Base URL", text: $viewModel.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("接口模式", selection: $viewModel.apiMode) {
                    ForEach(APIMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button("清除 API Key") {
                    viewModel.clearKey()
                }
                .foregroundColor(.red)

                Button(action: { viewModel.testConnection() }) {
                    HStack(spacing: 8) {
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

            Section(header: Text("模型")) {
                TextField("默认模型", text: $viewModel.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Text("温度")
                    Spacer()
                    Text(String(format: "%.2f", viewModel.temperature))
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.temperature, in: 0...11, step: 0.05)

                Stepper(value: $viewModel.maxTokens, in: 64...8192, step: 64) {
                    Text("最大 Tokens：\(viewModel.maxTokens)")
                }

                Toggle("流式输出", isOn: $viewModel.stream)
            }
        }
        .navigationTitle("设置")
    }
}
