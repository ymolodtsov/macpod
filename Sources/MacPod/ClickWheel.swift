import SwiftUI

enum WheelButton {
    case menu, next, prev, playPause, center
}

/// 1st-gen Nano style clickwheel. Colours come from a `NanoTheme` so the
/// wheel looks right on both the white and black iPod shells.
struct ClickWheel: View {
    let theme: NanoTheme
    var onPress: (WheelButton) -> Void

    private var pressedColor: Color { Color.white.opacity(0.45) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let ringOuter = side
            let ringInner = side * 0.40
            let centerSize = side * 0.38

            ZStack {
                // Grey ring (donut)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.wheelRingTop, theme.wheelRingBottom],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(theme.wheelOutline, lineWidth: 0.5)
                    )
                    .frame(width: ringOuter, height: ringOuter)
                    .mask(
                        Canvas { ctx, size in
                            let outer = Path(ellipseIn: CGRect(origin: .zero, size: size))
                            let innerRect = CGRect(
                                x: (size.width - ringInner) / 2,
                                y: (size.height - ringInner) / 2,
                                width: ringInner,
                                height: ringInner
                            )
                            let inner = Path(ellipseIn: innerRect)
                            ctx.fill(outer, with: .color(.white))
                            ctx.blendMode = .destinationOut
                            ctx.fill(inner, with: .color(.white))
                        }
                    )

                let labelOffset = (ringOuter + ringInner) / 4

                WheelLabel(text: "MENU", normal: theme.wheelGlyph, pressed: pressedColor) {
                    onPress(.menu)
                }
                .position(x: side / 2, y: side / 2 - labelOffset)

                WheelGlyph(system: "backward.end.alt.fill", normal: theme.wheelGlyph, pressed: pressedColor) {
                    onPress(.prev)
                }
                .position(x: side / 2 - labelOffset, y: side / 2)

                WheelGlyph(system: "forward.end.alt.fill", normal: theme.wheelGlyph, pressed: pressedColor) {
                    onPress(.next)
                }
                .position(x: side / 2 + labelOffset, y: side / 2)

                WheelGlyph(system: "playpause.fill", normal: theme.wheelGlyph, pressed: pressedColor) {
                    onPress(.playPause)
                }
                .position(x: side / 2, y: side / 2 + labelOffset)

                // Center select
                Button(action: { onPress(.center) }) {
                    Circle()
                        .fill(theme.wheelCenter)
                        .overlay(
                            Circle().strokeBorder(theme.wheelCenterStroke, lineWidth: 0.5)
                        )
                        .frame(width: centerSize, height: centerSize)
                }
                .buttonStyle(.plain)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

private struct WheelLabel: View {
    let text: String
    let normal: Color
    let pressed: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.8)
                .frame(width: 46, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(WheelPressStyle(normal: normal, pressed: pressed))
    }
}

private struct WheelGlyph: View {
    let system: String
    let normal: Color
    let pressed: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(WheelPressStyle(normal: normal, pressed: pressed))
    }
}

private struct WheelPressStyle: ButtonStyle {
    let normal: Color
    let pressed: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? pressed : normal)
    }
}
