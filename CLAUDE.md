# MacPod

A tiny 1st-gen iPod Nano on the Mac desktop that controls whatever's playing via the system "Now Playing" (Apple Music, Spotify, browsers, podcast apps, etc.). Menu bar app (`LSUIElement`), floating or windowed.

## Stack

- Swift 5.9, AppKit + SwiftUI. Built with SwiftPM (no Xcode project).
- Bundled `MediaRemoteAdapter.framework` + `mediaremote-adapter.pl` (from [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)) to talk to macOS's private MediaRemote on modern macOS.
- Min target: macOS 13.

## Layout

- `Sources/MacPod/` — app code
  - `main.swift` — entry point
  - `StatusBarController.swift` — menu bar icon + menu
  - `NanoPanel.swift` / `NanoView.swift` — the iPod window/view
  - `ClickWheel.swift` — clickwheel UI (uses SF Symbols `backward.end.alt.fill`, `forward.end.alt.fill`, `playpause.fill`)
  - `NowPlaying.swift` / `NowPlayingService.swift` — media remote integration
  - `BatteryMonitor.swift` — Mac battery → on-screen indicator
  - `Settings.swift` — theme/mode preferences
- `Resources/` — `.icns`, `icon.iconset/`, bundled framework + perl shim
- `Scripts/`
  - `build-app.sh` — builds `build/MacPod.app`, writes Info.plist, ad-hoc codesigns. **Version lives here** (`CFBundleVersion`, `CFBundleShortVersionString`).
  - `make-icon.swift` — renders the app icon programmatically (rounded body + clickwheel + SF Symbol glyphs), then runs `iconutil` to assemble `MacPod.icns`.
  - `rebuild-adapter.sh` — rebuilds the vendored media-remote adapter (needs `cmake`, `ninja`).
- `Vendor/` — upstream adapter source.

## Build / run

```sh
./Scripts/build-app.sh         # → build/MacPod.app
open build/MacPod.app
swift Scripts/make-icon.swift Resources   # regenerate icon after edits
```

## Versioning

Bump **both** `CFBundleVersion` and `CFBundleShortVersionString` in `Scripts/build-app.sh` for any release — macOS caches the icon by bundle identity, so shipping a new icon without a version bump leaves users on the old cached one.

## Conventions

- Clickwheel glyphs are the source of truth. If the icon's transport glyphs need to change, update `make-icon.swift` to pull the same SF Symbol names used in `ClickWheel.swift`.
- Themed colors (white vs black shell) come from `NanoTheme`; follow that pattern when adding chrome.
