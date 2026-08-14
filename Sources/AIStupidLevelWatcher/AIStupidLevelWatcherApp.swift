import AppKit
import SwiftUI

private enum IconAssets {
    static let statusBar: NSImage = {
        guard let url = Bundle.main.url(forResource: "StatusBarIcon", withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("StatusBarIcon.pdf is required in the app bundle")
        }
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        return image
    }()
}

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
            MenuContentView(store: store, notchIsland: notchIsland)
        } label: {
            Image(nsImage: IconAssets.statusBar)
                .renderingMode(.template)
                .accessibilityLabel(store.statusBarTitle)
        }
        .menuBarExtraStyle(.menu)
    }
}
