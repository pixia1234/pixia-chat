import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        TabView {
            Group {
                if horizontalSizeClass == .regular {
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

            NavigationView {
                SettingsView(viewModel: SettingsViewModel(store: settings))
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
        }
        .tint(Color(red: 0.2, green: 0.72, blue: 0.9))
    }
}
