import AppKit

// NSPanel subclass — panels participate in cross-Space window placement in a
// way that NSWindow does not. Combined with isFloatingPanel = true and
// collectionBehavior .canJoinAllSpaces, this is what keeps GhostTerm visible
// over apps in macOS fullscreen mode.
final class GhostWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "GhostTerm"

        // Never visible in screen recording / sharing / screencapture CLI.
        sharingType = .none

        // ALWAYS on top — including over apps that entered macOS fullscreen mode.
        // The combination that actually works:
        //   - NSPanel (not NSWindow)
        //   - isFloatingPanel = true
        //   - .canJoinAllSpaces in collectionBehavior
        //   - level = .statusBar (a high level that the OS does NOT cull in user Spaces).
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        worksWhenModal = true

        // Transparent panel so the terminal can composite at any alpha.
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        center()
    }

    // A non-activating panel must explicitly opt in to becoming key, otherwise
    // it can't receive keystrokes.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
