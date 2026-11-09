import AppKit
import SwiftUI
import XCTest
@testable import MacPod

final class ShadowTests: XCTestCase {
    @MainActor
    func testShadowFadesBeforeWindowBoundary() throws {
        for shell in ShellStyle.allCases {
            let renderer = ImageRenderer(content: NanoShadowShape(shell: shell))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.cgImage)
            let width = image.width
            let height = image.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            let context = try XCTUnwrap(CGContext(
                data: &pixels, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let alpha = { (x: Int, y: Int) in pixels[(y * width + x) * 4 + 3] }
            let edge = (0..<width).flatMap { [alpha($0, 0), alpha($0, height - 1)] }
                + (0..<height).flatMap { [alpha(0, $0), alpha(width - 1, $0)] }
            XCTAssertEqual(edge.max(), 0, "\(shell): shadow is clipped at the window edge")
            XCTAssertGreaterThan(pixels.enumerated().filter { $0.offset % 4 == 3 }.map(\.element).max() ?? 0,
                                 40, "The rendered shadow must not be empty")
        }
    }

    @MainActor
    func testShadowTracksBothShellsAndWindowModes() {
        let suite = "MacPodTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for mode in WindowMode.allCases {
            let panel = NanoPanel(rootView: Color.clear, size: ShellStyle.nano6.size,
                                  mode: mode, positionDefaults: defaults)
            let shadow = NanoShadowPanel(rootView: Color.clear, size: ShellStyle.nano6.shadowSize, mode: mode)
            panel.attachShadowPanel(shadow)
            defer { panel.close() }

            for shell in [ShellStyle.nano6, .nano1, .nano6] {
                panel.apply(shell: shell)
                for nextMode in [mode, mode == .floating ? .window : .floating] {
                    panel.apply(mode: nextMode)
                    XCTAssertEqual(shadow.frame, panel.frame.insetBy(
                        dx: -NanoMetrics.shadowMargin, dy: -NanoMetrics.shadowMargin))
                    XCTAssertEqual(shadow.level, panel.level)
                    XCTAssertEqual(shadow.collectionBehavior, panel.collectionBehavior)
                    XCTAssertTrue(shadow.ignoresMouseEvents)
                    XCTAssertTrue(shadow.parent === panel)
                }
            }
        }
    }
}
