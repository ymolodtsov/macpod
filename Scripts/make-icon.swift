#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Draws the MacPod app icon: rounded-square background with a centered
// clickwheel (grey ring, white glyphs, white center button). Writes all
// sizes required for iconutil into <out>/icon.iconset, then assembles
// MacPod.icns.

let outRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build")
let iconset = outRoot.appendingPathComponent("icon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

struct Spec { let name: String; let px: Int }
let specs: [Spec] = [
    .init(name: "icon_16x16.png",       px: 16),
    .init(name: "icon_16x16@2x.png",    px: 32),
    .init(name: "icon_32x32.png",       px: 32),
    .init(name: "icon_32x32@2x.png",    px: 64),
    .init(name: "icon_128x128.png",     px: 128),
    .init(name: "icon_128x128@2x.png",  px: 256),
    .init(name: "icon_256x256.png",     px: 256),
    .init(name: "icon_256x256@2x.png",  px: 512),
    .init(name: "icon_512x512.png",     px: 512),
    .init(name: "icon_512x512@2x.png",  px: 1024),
]

func render(px: Int) -> CGImage {
    let s = CGFloat(px)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                       bytesPerRow: 0, space: cs,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // macOS icon safe area: leave ~10% margin.
    let margin: CGFloat = s * 0.10
    let bodyRect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let bodyCorner = bodyRect.width * 0.2237  // squircle-ish

    // Background: soft white with a subtle top-to-bottom gradient.
    let bgPath = CGPath(roundedRect: bodyRect, cornerWidth: bodyCorner, cornerHeight: bodyCorner, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let bgColors = [
        CGColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        CGColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1),
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1])!
    ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: bodyRect.maxY),
                           end: CGPoint(x: 0, y: bodyRect.minY), options: [])
    ctx.restoreGState()

    // Thin stroke on the body to anchor it visually.
    ctx.addPath(bgPath)
    ctx.setLineWidth(max(1, s * 0.004))
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
    ctx.strokePath()

    // Clickwheel geometry.
    let cx = bodyRect.midX
    let cy = bodyRect.midY
    let ringOuter = bodyRect.width * 0.78
    let ringInner = ringOuter * 0.40
    let centerDia = ringOuter * 0.38

    // Ring: grey gradient donut.
    ctx.saveGState()
    let outerRect = CGRect(x: cx - ringOuter/2, y: cy - ringOuter/2, width: ringOuter, height: ringOuter)
    let innerRect = CGRect(x: cx - ringInner/2, y: cy - ringInner/2, width: ringInner, height: ringInner)
    let donut = CGMutablePath()
    donut.addEllipse(in: outerRect)
    donut.addEllipse(in: innerRect)
    ctx.addPath(donut)
    ctx.clip(using: .evenOdd)

    let ringColors = [
        CGColor(red: 0.80, green: 0.81, blue: 0.82, alpha: 1),
        CGColor(red: 0.67, green: 0.68, blue: 0.70, alpha: 1),
    ] as CFArray
    let ringGrad = CGGradient(colorsSpace: cs, colors: ringColors, locations: [0, 1])!
    ctx.drawLinearGradient(ringGrad, start: CGPoint(x: 0, y: outerRect.maxY),
                           end: CGPoint(x: 0, y: outerRect.minY), options: [])
    ctx.restoreGState()

    // Ring outline.
    ctx.addEllipse(in: outerRect)
    ctx.setLineWidth(max(1, s * 0.003))
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.12))
    ctx.strokePath()

    // Center button.
    let centerRect = CGRect(x: cx - centerDia/2, y: cy - centerDia/2, width: centerDia, height: centerDia)
    ctx.saveGState()
    ctx.addEllipse(in: centerRect)
    ctx.clip()
    let centerColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
        CGColor(red: 0.94, green: 0.94, blue: 0.95, alpha: 1),
    ] as CFArray
    let centerGrad = CGGradient(colorsSpace: cs, colors: centerColors, locations: [0, 1])!
    ctx.drawLinearGradient(centerGrad, start: CGPoint(x: 0, y: centerRect.maxY),
                           end: CGPoint(x: 0, y: centerRect.minY), options: [])
    ctx.restoreGState()
    ctx.addEllipse(in: centerRect)
    ctx.setLineWidth(max(1, s * 0.003))
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.12))
    ctx.strokePath()

    // Glyphs: white, positioned on the ring's midline.
    let glyphR = (ringOuter + ringInner) / 4
    let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

    // MENU (top): a simple word in a clean font at bigger sizes; at small
    // sizes the text would smear, so draw a bold horizontal bar instead.
    let menuCenter = CGPoint(x: cx, y: cy + glyphR)  // CG y-up
    if px >= 128 {
        let str = NSAttributedString(string: "MENU", attributes: [
            .font: NSFont.systemFont(ofSize: s * 0.048, weight: .heavy),
            .foregroundColor: NSColor.white,
            .kern: s * 0.004,
        ])
        let line = CTLineCreateWithAttributedString(str)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        ctx.saveGState()
        ctx.textPosition = CGPoint(x: menuCenter.x - bounds.width/2,
                                   y: menuCenter.y - bounds.height/2 - bounds.origin.y)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    } else {
        // Tiny sizes: stylized bar.
        let barW = s * 0.09
        let barH = s * 0.018
        let r = CGRect(x: menuCenter.x - barW/2, y: menuCenter.y - barH/2, width: barW, height: barH)
        ctx.setFillColor(white)
        ctx.fill(r)
    }

    // Draw an SF Symbol centered at `center`, rendered white, fitting `box`.
    // Uses NSImage(systemSymbolName:) so glyphs match what ClickWheel.swift
    // uses — prev/next/playpause must look identical on icon and wheel.
    func drawSymbol(_ name: String, at center: CGPoint, box: CGSize) {
        let config = NSImage.SymbolConfiguration(pointSize: box.height, weight: .heavy)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) else { return }
        // Tint to white by drawing through a template.
        let tinted = NSImage(size: base.size, flipped: false) { rect in
            NSColor.white.set()
            rect.fill()
            base.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
            return true
        }
        // Scale preserving aspect ratio to fit within `box`.
        let srcAspect = base.size.width / max(base.size.height, 0.001)
        var w = box.width
        var h = box.height
        if srcAspect > w / h { h = w / srcAspect } else { w = h * srcAspect }
        let rect = CGRect(x: center.x - w/2, y: center.y - h/2, width: w, height: h)
        var imgRect = CGRect(origin: .zero, size: tinted.size)
        if let cg = tinted.cgImage(forProposedRect: &imgRect, context: nil, hints: nil) {
            ctx.draw(cg, in: rect)
        }
    }

    let glyphBox = CGSize(width: s * 0.095, height: s * 0.055)
    drawSymbol("backward.end.alt.fill", at: CGPoint(x: cx - glyphR, y: cy), box: glyphBox)
    drawSymbol("forward.end.alt.fill",  at: CGPoint(x: cx + glyphR, y: cy), box: glyphBox)
    drawSymbol("playpause.fill",        at: CGPoint(x: cx, y: cy - glyphR), box: glyphBox)
    _ = white

    return ctx.makeImage()!
}

for spec in specs {
    let img = render(px: spec.px)
    let url = iconset.appendingPathComponent(spec.name)
    let rep = NSBitmapImageRep(cgImage: img)
    rep.size = NSSize(width: spec.px, height: spec.px)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: url)
    print("wrote \(url.path)")
}

// Assemble .icns.
let icns = outRoot.appendingPathComponent("MacPod.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try p.run()
p.waitUntilExit()
print("wrote \(icns.path)")
