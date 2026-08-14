import AppKit
import SwiftUI

@main
struct AIStupidLevelWatcherApp: App {
    @StateObject private var store: LeaderboardStore
    private let notchIsland: NotchIslandController

    init() {
        let controller = NotchIslandController()
        notchIsland = controller
        _store = StateObject(
            wrappedValue: LeaderboardStore { snapshot in
                controller.update(snapshot: snapshot)
            }
        )
        // A panel created while SwiftUI is constructing StateObject can abort
        // AttributeGraph. Defer the initial compact state to the next run loop.
        DispatchQueue.main.async {
            controller.update(snapshot: nil)
        }
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
