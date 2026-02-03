import SwiftUI
import UIKit

struct SettingsSplitView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selection: String? = "settings"
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationSplitView(columnVisibility: .constant(.all)) {
                    List(selection: $selection) {
                        Label("设置", systemImage: "gear")
                            .tag("settings")
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("设置")
                } detail: {
                    SettingsView(viewModel: SettingsViewModel(store: settings))
                }
            } else if isPad {
                LegacySplitView(
                    primary: NavigationView { settingsSidebar }
                        .navigationViewStyle(StackNavigationViewStyle()),
                    secondary: NavigationView {
                        SettingsView(viewModel: SettingsViewModel(store: settings))
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                )
            } else {
                NavigationView {
                    List {
                        Label("设置", systemImage: "gear")
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("设置")

                    SettingsView(viewModel: SettingsViewModel(store: settings))
                }
                .navigationViewStyle(DoubleColumnNavigationViewStyle())
            }
        }
    }

    private var settingsSidebar: some View {
        List(selection: $selection) {
            Label("设置", systemImage: "gear")
                .tag("settings")
        }
        .listStyle(.sidebar)
        .navigationTitle("设置")
    }
}
