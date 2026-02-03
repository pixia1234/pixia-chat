import SwiftUI

struct SettingsSplitView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selection: String? = "settings"

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationSplitView {
                    List(selection: $selection) {
                        Label("设置", systemImage: "gear")
                            .tag("settings")
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("设置")
                } detail: {
                    SettingsView(viewModel: SettingsViewModel(store: settings))
                }
            } else {
                NavigationView {
                    List {
                        Label("设置", systemImage: "gear")
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("设置")

                    SettingsView(viewModel: SettingsViewModel(store: settings))
                }
                .navigationViewStyle(.columns)
            }
        }
    }
}
