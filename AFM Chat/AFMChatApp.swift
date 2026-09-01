import SwiftUI

@main
struct AFMChatApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var store: ChatStore
    @StateObject private var controller: ChatController

    init() {
        let settings = AppSettings()
        let store = ChatStore()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: store)
        _controller = StateObject(wrappedValue: ChatController(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(controller)
                .frame(minWidth: 880, minHeight: 620)
        }
        .defaultSize(width: 1120, height: 760)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(controller)
                .frame(width: 560, height: 430)
        }
    }
}
