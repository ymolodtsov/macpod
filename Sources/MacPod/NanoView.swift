import SwiftUI

struct NanoView: View {
    @ObservedObject var service: NowPlayingService
    @ObservedObject var settings: AppSettings
    @ObservedObject var battery: BatteryMonitor
    var onMenu: () -> Void = {}
    @Environment(\.colorScheme) private var systemColorScheme

    private var theme: NanoTheme {
        NanoTheme.resolve(mode: settings.colorMode, systemIsDark: systemColorScheme == .dark)
    }

    var body: some View {
        ZStack {
            bodyShape
                .shadow(color: .black.opacity(0.22), radius: 48, x: 0, y: 28)
                .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)

            VStack(spacing: 0) {
                screen
                    .padding(.horizontal, NanoMetrics.screenSideInset)
                    .padding(.top, NanoMetrics.screenTopInset)
                Spacer(minLength: 0)
                ClickWheel(theme: theme, onPress: handle)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, NanoMetrics.wheelSideInset)
                Spacer(minLength: 0)
            }
            .frame(width: NanoMetrics.bodyWidth, height: NanoMetrics.bodyHeight)
        }
        .frame(width: NanoMetrics.windowWidth, height: NanoMetrics.windowHeight)
    }

    private var bodyShape: some View {
        RoundedRectangle(cornerRadius: NanoMetrics.bodyCorner, style: .continuous)
            .fill(theme.body)
            .overlay(
                RoundedRectangle(cornerRadius: NanoMetrics.bodyCorner, style: .continuous)
                    .strokeBorder(theme.bodyStroke, lineWidth: 0.5)
            )
            .frame(width: NanoMetrics.bodyWidth, height: NanoMetrics.bodyHeight)
    }

    // MARK: - Screen (identical across themes — the iPod "display")

    private var screen: some View {
        VStack(spacing: 0) {
            headerBar.frame(height: 18)

            ZStack {
                Color.white
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.state.trackNumber.map { "Track \($0)" } ?? "Track")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .opacity(service.state.trackNumber == nil ? 0 : 1)
                    HStack(alignment: .top, spacing: 6) {
                        artworkView
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
                            )
                        VStack(alignment: .leading, spacing: 0) {
                            Text(service.state.title ?? "")
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(service.state.artist ?? "")
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(service.state.album ?? "")
                                .lineLimit(1)
                        }
                        .frame(height: 52, alignment: .leading)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                    stripedProgressBar
                    HStack {
                        Text(formatTime(service.state.elapsed ?? 0))
                        Spacer()
                        Text("-" + formatTime(max((service.state.duration ?? 0) - (service.state.elapsed ?? 0), 0)))
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5)
        )
        .aspectRatio(1.05, contentMode: .fit)
    }

    private var headerBar: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.96), Color(white: 0.82)],
                startPoint: .top, endPoint: .bottom
            )
            HStack(spacing: 0) {
                Image(systemName: service.state.isPlaying ? "play.fill" : "pause.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(red: 0.10, green: 0.60, blue: 0.88))
                    .padding(.leading, 5)
                Spacer(minLength: 0)
                Text("Now Playing")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.black)
                Spacer(minLength: 0)
                batteryIcon.padding(.trailing, 5)
            }
        }
    }

    private var batteryIcon: some View {
        let bodyW: CGFloat = 14
        let bodyH: CGFloat = 7
        let innerMaxW: CGFloat = bodyW - 3  // leave 1px inset on left and right
        let level = CGFloat(battery.level)
        let fillW = max(0, innerMaxW * level)

        // Colour: green when healthy, amber below 30%, red below 15%
        let fillColor: LinearGradient = {
            if battery.level < 0.15 {
                return LinearGradient(
                    colors: [Color(red: 0.95, green: 0.35, blue: 0.25), Color(red: 0.82, green: 0.20, blue: 0.15)],
                    startPoint: .top, endPoint: .bottom
                )
            } else if battery.level < 0.30 {
                return LinearGradient(
                    colors: [Color(red: 0.98, green: 0.78, blue: 0.25), Color(red: 0.92, green: 0.60, blue: 0.10)],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                return LinearGradient(
                    colors: [Color(red: 0.58, green: 0.90, blue: 0.40), Color(red: 0.38, green: 0.78, blue: 0.28)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }()

        return HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .strokeBorder(Color.black.opacity(0.55), lineWidth: 0.7)
                    .frame(width: bodyW, height: bodyH)
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(fillColor)
                    .frame(width: fillW, height: bodyH - 2)
                    .padding(.leading, 1.5)
                if battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 5.5, weight: .black))
                        .foregroundColor(.black.opacity(0.7))
                        .frame(width: bodyW, height: bodyH)
                }
            }
            Rectangle().fill(Color.black.opacity(0.55)).frame(width: 1, height: 3)
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let img = service.state.artwork {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color(white: 0.92)
                Image(systemName: "music.note")
                    .foregroundColor(Color(white: 0.6))
                    .font(.system(size: 18))
            }
        }
    }

    private var stripedProgressBar: some View {
        let total = max(service.state.duration ?? 0, 0.0001)
        let frac = min(max((service.state.elapsed ?? 0) / total, 0), 1)
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let fillW = max(0, w * CGFloat(frac))

            ZStack(alignment: .leading) {
                // Pearl track — square corners
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.99), Color(white: 0.93), Color(white: 0.98)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                // Blurred blue+cyan stripes, hard-masked to fillW so the
                // right edge is crisp even though the stripes themselves
                // are internally blurred.
                Canvas { ctx, size in
                    let stripeW: CGFloat = 3.5
                    let blue = Color(red: 0.18, green: 0.42, blue: 0.80)
                    let cyan = Color(red: 0.35, green: 0.85, blue: 0.98)
                    var x: CGFloat = 0
                    var idx = 0
                    while x < size.width {
                        let rect = CGRect(x: x, y: 0, width: stripeW, height: size.height)
                        ctx.fill(Path(rect), with: .color(idx % 2 == 0 ? blue : cyan))
                        x += stripeW
                        idx += 1
                    }
                }
                .frame(width: w, height: h)
                .blur(radius: 2.0)
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.45), location: 0.0),
                            .init(color: Color.white.opacity(0.0), location: 0.55),
                            .init(color: Color.black.opacity(0.18), location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .mask(
                    Rectangle()
                        .frame(width: fillW, height: h)
                        .frame(width: w, height: h, alignment: .leading)
                )

                // Top inner highlight — square
                Rectangle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.75), Color.white.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
                    .blendMode(.plusLighter)

                // Outer outline — square, crisp
                Rectangle()
                    .strokeBorder(Color.black.opacity(0.30), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0.5)
        }
        .frame(height: 9)
    }

    private func formatTime(_ t: Double) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func handle(_ b: WheelButton) {
        switch b {
        case .playPause: service.send(.togglePlayPause)
        case .next: service.send(.nextTrack)
        case .prev: service.send(.previousTrack)
        case .menu: onMenu()
        case .center: break
        }
    }
}

enum NanoMetrics {
    static let bodyWidth: CGFloat = 180
    static let bodyHeight: CGFloat = 390
    static let bodyCorner: CGFloat = 14

    static let screenTopInset: CGFloat = 14
    static let screenSideInset: CGFloat = 14
    static let wheelSideInset: CGFloat = 22

    static let shadowMargin: CGFloat = 100
    static var windowWidth: CGFloat { bodyWidth + shadowMargin * 2 }
    static var windowHeight: CGFloat { bodyHeight + shadowMargin * 2 }
}
