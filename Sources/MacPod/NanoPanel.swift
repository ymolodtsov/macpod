import AppKit
import SwiftUI

/// A borderless, Nano-shaped window. Operates either as a floating panel
/// (always on top, joins all spaces) or as a regular window pinned to one
/// Mission Control space.
final class NanoPanel: NSPanel {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

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
        // AppKit constrains background-dragged windows by their full frame.
        // This panel's frame includes transparent shadow margins, so use an
        // application-controlled drag that constrains only the visible Nano.
        self.isMovable = false
        self.isMovableByWindowBackground = false
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

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartWindowOrigin = frame.origin

        case .leftMouseDragged:
            if let mouseStart = dragStartMouseLocation,
               let windowStart = dragStartWindowOrigin {
                let mouseNow = NSEvent.mouseLocation
                var proposedFrame = frame
                proposedFrame.origin = NSPoint(
                    x: windowStart.x + mouseNow.x - mouseStart.x,
                    y: windowStart.y + mouseNow.y - mouseStart.y
                )
                setFrameOrigin(constrainedOrigin(for: proposedFrame, mouseLocation: mouseNow))
            }

        case .leftMouseUp:
            dragStartMouseLocation = nil
            dragStartWindowOrigin = nil

        default:
            break
        }

        super.sendEvent(event)
    }

    private func constrainedOrigin(for proposedFrame: NSRect, mouseLocation: NSPoint) -> NSPoint {
        guard let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? screen
            ?? NSScreen.main else {
            return proposedFrame.origin
        }

        let visibleFrame = targetScreen.visibleFrame
        let nanoFrame = proposedFrame.insetBy(
            dx: NanoMetrics.shadowMargin,
            dy: NanoMetrics.shadowMargin
        )
        var origin = proposedFrame.origin

        if nanoFrame.minX < visibleFrame.minX {
            origin.x += visibleFrame.minX - nanoFrame.minX
        } else if nanoFrame.maxX > visibleFrame.maxX {
            origin.x -= nanoFrame.maxX - visibleFrame.maxX
        }

        if nanoFrame.minY < visibleFrame.minY {
            origin.y += visibleFrame.minY - nanoFrame.minY
        } else if nanoFrame.maxY > visibleFrame.maxY {
            origin.y -= nanoFrame.maxY - visibleFrame.maxY
        }

        return origin
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
