---
name: swiftui-notch-panel-stability
description: |
  Stabilize a SwiftUI-backed NSPanel or simulated macOS notch overlay. Use when
  an NSHostingView created from a SwiftUI MenuBarExtra crashes with AttributeGraph
  SIGABRT on startup or click, or when the overlay must sit above the menu bar.
---

# SwiftUI Notch Panel Stability

## Failure Mechanism

`@StateObject(wrappedValue:)` is evaluated while SwiftUI is building its
attribute graph. Creating or replacing an `NSHostingView` from that initializer,
or synchronously from a Button/hover callback, can re-enter the graph and abort
with an `AttributeGraph` precondition failure.

`NSScreen.visibleFrame` excludes the menu bar. A panel at `.statusBar` can still
be drawn below the system menu bar; its frame must use `screen.frame`, and a
notch overlay intended to cover the bar needs an appropriate higher level.

`NSPanel.isFloatingPanel = true` resets a previously assigned custom level to
`.floating`. Set that property before `.screenSaver`; otherwise WindowServer
reports layer `3` and clamps the panel below the menu bar instead of allowing
the physical top edge.

## Procedure

1. Keep AppKit panel ownership in an `ObservableObject` controller, separate
   from the app's `@StateObject` store.
2. Pass a snapshot callback into the store, but defer the controller's initial
   `update` with `DispatchQueue.main.async` after the app has initialized.
3. From click, hover, or snapshot callbacks, schedule panel content replacement
   on the next main-queue turn. Do not call `panel.contentView = NSHostingView(...)`
   synchronously inside a SwiftUI view event.
4. Use a SwiftUI `Button` for a compact island that needs to be testable or
   clickable. Confirm its AX tree exposes a `button`; do not assume an
   `onTapGesture` is accessible.
5. Set `isFloatingPanel` before the desired level. For an explicit physical-
   top simulated notch, use `.screenSaver` with `.canJoinAllSpaces`,
   `.canJoinAllApplications`, `.fullScreenAuxiliary`, and `.stationary`.
   Anchor it with `screen.frame.maxY - panelHeight`. Use `.statusBar` when
   covering the system menu bar is not a product requirement.
6. Keep the compact and expanded views in the same panel controller and verify
   both transitions before changing app-wide state.

## Verification

- Build the release target and run its focused tests.
- Install the app bundle and verify its LaunchAgent reports `state = running`.
- Capture a whole-screen screenshot: the compact island must start at the
  physical top edge, not below the menu bar.
- Inspect `CGWindowListCopyWindowInfo`: a physical-top screen-saver panel has
  `Y = 0` and layer `1000`; layer `3` means `isFloatingPanel` overwrote it.
- Use Accessibility to click the compact `button`; confirm the expanded rows
  appear and the same service PID remains alive with an empty error log.

## High-Risk Actions

- Do not construct a hosting panel in a SwiftUI state-object initializer.
- Do not replace panel content synchronously during a SwiftUI action or hover.
- Do not set `isFloatingPanel` after a custom `panel.level`.
- Do not use `visibleFrame` for a top-edge overlay. Reserve `.screenSaver` for
  a deliberately small, noncritical overlay because it sits above system UI.
- Do not describe a simulated panel as controlling the physical camera notch.
