import AppKit

/// Menu bar icon. Clicking it opens the context menu with Show/Hide,
/// Settings, transport controls, and Quit.
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let service: NowPlayingService
    private let isVisible: () -> Bool
    private let showPanel: () -> Void
    private let hidePanel: () -> Void
    private let showSettings: () -> Void

    init(
        service: NowPlayingService,
        isVisible: @escaping () -> Bool,
        showPanel: @escaping () -> Void,
        hidePanel: @escaping () -> Void,
        showSettings: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.service = service
        self.isVisible = isVisible
        self.showPanel = showPanel
        self.hidePanel = hidePanel
        self.showSettings = showSettings
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "playpause.fill", accessibilityDescription: "MacPod")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(buttonClicked(_:))
        }
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let toggleTitle = isVisible() ? "Hide" : "Show"
        menu.addItem(withTitle: toggleTitle, action: #selector(toggleAction), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Play / Pause", action: #selector(playPauseAction), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Next Track", action: #selector(nextAction), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Previous Track", action: #selector(prevAction), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(settingsAction), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Quit MacPod", action: #selector(quitAction), keyEquivalent: "q").target = self

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleAction() {
        if isVisible() { hidePanel() } else { showPanel() }
    }
    @objc private func playPauseAction() { service.send(.togglePlayPause) }
    @objc private func nextAction() { service.send(.nextTrack) }
    @objc private func prevAction() { service.send(.previousTrack) }
    @objc private func settingsAction() { showSettings() }
    @objc private func quitAction() { NSApp.terminate(nil) }
}
