import AppKit
import SwiftUI

@main
struct AIStupidLevelWatcherApp: App {
    @StateObject private var store: LeaderboardStore
    private let dynamicIsland: DynamicIslandController

    init() {
        let controller = DynamicIslandController()
        dynamicIsland = controller
        _store = StateObject(
            wrappedValue: LeaderboardStore { snapshot in
                controller.update(snapshot: snapshot)
            }
        )
        // Keep this as a menu-bar utility instead of adding a Dock icon.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            Label(store.statusBarTitle, systemImage: "chart.bar.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}
