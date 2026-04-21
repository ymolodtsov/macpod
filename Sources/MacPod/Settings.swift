import SwiftUI
import AppKit

enum ColorMode: String, CaseIterable, Identifiable {
    case system, white, black
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "Follow System"
        case .white: return "White"
        case .black: return "Black"
        }
    }
}

enum WindowMode: String, CaseIterable, Identifiable {
    case floating, window
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .floating: return "Floating"
        case .window: return "Window"
        }
    }
}

final class AppSettings: ObservableObject {
    @AppStorage("colorMode") var colorModeRaw: String = ColorMode.system.rawValue {
        willSet { objectWillChange.send() }
    }
    var colorMode: ColorMode {
        get { ColorMode(rawValue: colorModeRaw) ?? .system }
        set { colorModeRaw = newValue.rawValue }
    }

    @AppStorage("windowMode") var windowModeRaw: String = WindowMode.floating.rawValue {
        willSet { objectWillChange.send() }
    }
    var windowMode: WindowMode {
        get { WindowMode(rawValue: windowModeRaw) ?? .floating }
        set { windowModeRaw = newValue.rawValue }
    }
}

/// Resolved palette for the Nano shell. Screen contents stay the same.
struct NanoTheme {
    let body: Color
    let bodyStroke: Color
    let wheelRingTop: Color
    let wheelRingBottom: Color
    let wheelOutline: Color
    let wheelCenter: Color
    let wheelCenterStroke: Color
    let wheelGlyph: Color

    static let white = NanoTheme(
        body: .white,
        bodyStroke: Color.black.opacity(0.08),
        wheelRingTop: Color(red: 0.78, green: 0.79, blue: 0.80),
        wheelRingBottom: Color(red: 0.68, green: 0.69, blue: 0.71),
        wheelOutline: Color.black.opacity(0.10),
        wheelCenter: .white,
        wheelCenterStroke: Color.black.opacity(0.10),
        wheelGlyph: .white
    )

    static let black = NanoTheme(
        body: Color(white: 0.03),
        bodyStroke: Color.white.opacity(0.06),
        wheelRingTop: Color(white: 0.22),
        wheelRingBottom: Color(white: 0.13),
        wheelOutline: Color.white.opacity(0.06),
        wheelCenter: Color(white: 0.10),
        wheelCenterStroke: Color.white.opacity(0.08),
        wheelGlyph: .white
    )

    static func resolve(mode: ColorMode, systemIsDark: Bool) -> NanoTheme {
        switch mode {
        case .white: return .white
        case .black: return .black
        case .system: return systemIsDark ? .black : .white
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Color", selection: Binding(
                        get: { settings.colorMode },
                        set: { settings.colorMode = $0 }
                    )) {
                        ForEach(ColorMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    Picker("Window", selection: Binding(
                        get: { settings.windowMode },
                        set: { settings.windowMode = $0 }
                    )) {
                        ForEach(WindowMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: "https://github.com/ymolodtsov/macpod") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Get Updates", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Quit MacPod") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 340, height: 300)
    }
}

final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: AppSettings

    init(settings: AppSettings) { self.settings = settings }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let content = SettingsView(settings: settings)
        let hosting = NSHostingController(rootView: content)
        let w = NSWindow(contentViewController: hosting)
        w.title = "MacPod Settings"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = w
    }
}
