import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        TabView {
            NavigationView {
                ChatListView()
            }
            .tabItem {
                Label("Chats", systemImage: "message")
            }

            NavigationView {
                SettingsView(viewModel: SettingsViewModel(store: settings))
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}
