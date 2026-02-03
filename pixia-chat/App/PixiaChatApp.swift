import SwiftUI

@main
struct PixiaChatApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(settingsStore)
        }
    }
}
