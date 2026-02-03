import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        TabView {
            Group {
                if isPad || horizontalSizeClass == .regular {
                    ChatSplitView()
                } else {
                    NavigationView {
                        ChatListView()
                    }
                }
            }
            .tabItem {
                Label("对话", systemImage: "message")
            }

            Group {
                if isPad || horizontalSizeClass == .regular {
                    SettingsSplitView()
                } else {
                    NavigationView {
                        SettingsView(viewModel: SettingsViewModel(store: settings))
                    }
                }
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
        }
        .tint(Color(red: 0.2, green: 0.72, blue: 0.9))
    }
}
