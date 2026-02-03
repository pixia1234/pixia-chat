import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section(header: Text("API"), footer: Text("API Key is stored in Keychain on this device.")) {
                SecureField("API Key", text: $viewModel.apiKey)
                TextField("Base URL", text: $viewModel.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("API Mode", selection: $viewModel.apiMode) {
                    ForEach(APIMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button("Clear API Key") {
                    viewModel.clearKey()
                }
                .foregroundColor(.red)
            }

            Section(header: Text("Model")) {
                TextField("Default Model", text: $viewModel.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(String(format: "%.2f", viewModel.temperature))
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.temperature, in: 0...2, step: 0.05)

                Stepper(value: $viewModel.maxTokens, in: 64...8192, step: 64) {
                    Text("Max Tokens: \(viewModel.maxTokens)")
                }

                Toggle("Stream", isOn: $viewModel.stream)
            }
        }
        .navigationTitle("Settings")
    }
}
