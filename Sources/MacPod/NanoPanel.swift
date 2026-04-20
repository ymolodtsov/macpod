import AppKit
import SwiftUI

/// A borderless, Nano-shaped window. Operates either as a floating panel
/// (always on top, joins all spaces) or as a regular window pinned to one
/// Mission Control space.
final class NanoPanel: NSPanel {
    init<Content: View>(rootView: Content, size: CGSize, mode: WindowMode) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.hasShadow = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting

        apply(mode: mode)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.maxX - size.width - 32,
                y: visible.maxY - size.height - 32
            )
            self.setFrameOrigin(origin)
        }
    }

    func apply(mode: WindowMode) {
        switch mode {
        case .floating:
            self.isFloatingPanel = true
            self.level = .floating
            self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        case .window:
            self.isFloatingPanel = false
            self.level = .normal
            self.collectionBehavior = [.managed, .participatesInCycle]
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
