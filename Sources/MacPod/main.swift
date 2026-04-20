import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NanoPanel?
    var service: NowPlayingService?
    var statusBar: StatusBarController?
    let settings = AppSettings()
    let battery = BatteryMonitor()
    lazy var settingsWindow = SettingsWindowController(settings: settings)
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let service = NowPlayingService() else {
            NSLog("[macpod] fatal: missing adapter resources")
            NSApp.terminate(nil)
            return
        }
        self.service = service
        service.start()

        let root = NanoView(
            service: service,
            settings: settings,
            battery: battery,
            onMenu: { [weak self] in self?.settingsWindow.show() }
        )
        let panel = NanoPanel(
            rootView: root,
            size: CGSize(width: NanoMetrics.windowWidth, height: NanoMetrics.windowHeight),
            mode: settings.windowMode
        )
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.panel?.apply(mode: self.settings.windowMode)
                }
            }
            .store(in: &cancellables)

        self.statusBar = StatusBarController(
            service: service,
            isVisible: { [weak self] in self?.panel?.isVisible ?? false },
            showPanel: { [weak self] in self?.showPanel() },
            hidePanel: { [weak self] in self?.hidePanel() },
            showSettings: { [weak self] in self?.settingsWindow.show() }
        )

        NSApp.setActivationPolicy(.accessory)
    }

    private func showPanel() {
        panel?.makeKeyAndOrderFront(nil)
    }

    private func hidePanel() {
        panel?.orderOut(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        service?.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
