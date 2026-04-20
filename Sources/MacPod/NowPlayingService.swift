import Foundation
import AppKit
import Combine

/// Wraps the bundled mediaremote-adapter: spawns the perl shim as a long-lived
/// streaming subprocess and publishes `NowPlaying` state. Sends playback
/// commands via short-lived perl invocations.
///
/// Timing model:
///  - Authoritative state is an `Anchor(elapsed, at, rate)` computed from the
///    last event. Between events, the "ideal" elapsed is
///    `anchor.elapsed + rate * (now - anchor.at)`.
///  - A 100ms ticker advances `displayedElapsed` locally.
///  - Small corrections from the media app (±1.5s) are absorbed via a
///    monotonic "never regress" rule — the display holds while reality
///    catches up. Large deltas (scrub, track change) snap.
///  - User actions are applied optimistically: tapping pause locks the
///    anchor at the currently displayed value and flips rate to 0. When the
///    real event arrives it lands inside the deadband and is invisible.
final class NowPlayingService: ObservableObject {
    @Published private(set) var state: NowPlaying = .empty

    private var streamTask: Process?
    private var stdoutHandle: FileHandle?
    private var buffer = Data()
    private let queue = DispatchQueue(label: "macpod.nowplaying")

    private struct Anchor {
        var elapsed: Double
        var at: Date
        var rate: Double
    }
    private var anchor: Anchor?
    private var displayedElapsed: Double = 0
    private var lastTitle: String?

    private var ticker: Timer?
    private let tickInterval: TimeInterval = 0.1
    private let snapThreshold: Double = 1.5
    private let forwardOvershootAllowed: Double = 0.3

    // Sticky expectation after an optimistic user action: ignore incoming
    // play/pause reports that contradict it until the real event catches up
    // or the window expires. Prevents the header icon from flipping back
    // momentarily when a stale "still playing" event arrives right after
    // the user hit pause.
    private var expectedPlaying: Bool?
    private var expectedUntil: Date = .distantPast
    private let expectationWindow: TimeInterval = 1.2

    private let perlPath = "/usr/bin/perl"
    private let frameworkURL: URL
    private let scriptURL: URL
    private lazy var isoFormatter: ISO8601DateFormatter = ISO8601DateFormatter()

    init?() {
        let bundle = Bundle.main
        let candidates: [URL] = [
            bundle.resourceURL,
            bundle.bundleURL.appendingPathComponent("Contents/Resources"),
            bundle.bundleURL.deletingLastPathComponent().appendingPathComponent("Resources"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
        ].compactMap { $0 }

        var framework: URL?
        var script: URL?
        for base in candidates {
            let fw = base.appendingPathComponent("MediaRemoteAdapter.framework")
            let sc = base.appendingPathComponent("mediaremote-adapter.pl")
            if FileManager.default.fileExists(atPath: fw.path) && FileManager.default.fileExists(atPath: sc.path) {
                framework = fw
                script = sc
                break
            }
        }
        guard let fw = framework, let sc = script else {
            NSLog("[macpod] adapter resources not found")
            return nil
        }
        self.frameworkURL = fw
        self.scriptURL = sc
    }

    func start() {
        stop()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: perlPath)
        p.arguments = [scriptURL.path, frameworkURL.path, "stream", "--no-diff"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.standardError
        stdoutHandle = out.fileHandleForReading
        stdoutHandle?.readabilityHandler = { [weak self] fh in
            let chunk = fh.availableData
            guard !chunk.isEmpty else { return }
            self?.queue.async { self?.ingest(chunk) }
        }
        do {
            try p.run()
            streamTask = p
        } catch {
            NSLog("[macpod] failed to start adapter: %@", String(describing: error))
        }
        startTicker()
    }

    func stop() {
        stdoutHandle?.readabilityHandler = nil
        stdoutHandle = nil
        streamTask?.terminate()
        streamTask = nil
        buffer.removeAll()
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - Stream ingest

    private func ingest(_ data: Data) {
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: 0..<nl)
            buffer.removeSubrange(0...nl)
            guard !line.isEmpty else { continue }
            handleLine(line)
        }
    }

    private func handleLine(_ line: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return }
        let payload = (obj["payload"] as? [String: Any]) ?? obj
        let type = obj["type"] as? String

        let reportedElapsed = payload["elapsedTime"] as? Double
        let reportedRate: Double? = {
            if let r = payload["playbackRate"] as? Double { return r }
            if let p = payload["playing"] as? Bool { return p ? 1.0 : 0.0 }
            switch type {
            case "playing": return 1.0
            case "paused", "stopped": return 0.0
            default: return nil
            }
        }()
        let reportedAt: Date? = (payload["timestamp"] as? String).flatMap { self.isoFormatter.date(from: $0) }
        let reportedTitle = payload["title"] as? String

        // Carry forward existing state and patch in anything the event has.
        var np = state
        if let title = payload["title"] as? String { np.title = title }
        if let artist = payload["artist"] as? String { np.artist = artist }
        if let album = payload["album"] as? String { np.album = album }
        if let duration = payload["duration"] as? Double { np.duration = duration }
        if let bid = payload["bundleIdentifier"] as? String { np.bundleIdentifier = bid }
        if let tn = payload["trackNumber"] as? Int { np.trackNumber = tn }
        if let rate = reportedRate { np.isPlaying = rate > 0.001 }
        if let b64 = payload["artworkData"] as? String,
           let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters),
           let img = NSImage(data: data) {
            np.artwork = img
        }

        var snapshot = np
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Reconcile incoming play/pause against any sticky expectation
            // from a recent optimistic user action.
            if let incoming = reportedRate.map({ $0 > 0.001 }) {
                if let expected = self.expectedPlaying,
                   Date() < self.expectedUntil,
                   incoming != expected {
                    snapshot.isPlaying = expected
                } else if let expected = self.expectedPlaying, incoming == expected {
                    self.expectedPlaying = nil
                }
            }

            self.state = snapshot

            // Track change: snap display, don't deadband.
            var trackChanged = false
            if let t = reportedTitle, t != self.lastTitle {
                self.lastTitle = t
                trackChanged = true
            }

            if let e = reportedElapsed {
                let at = reportedAt ?? Date()
                let rate = reportedRate ?? (snapshot.isPlaying ? 1.0 : 0.0)
                self.anchor = Anchor(elapsed: e, at: at, rate: rate)
                if trackChanged {
                    self.displayedElapsed = e
                }
                // Otherwise the ticker reconciles with the deadband rule.
            } else if let rate = reportedRate {
                // No new elapsed but rate changed — update rate without moving
                // the anchor's time reference relative to displayed.
                if var a = self.anchor {
                    a.rate = rate
                    a.elapsed = self.displayedElapsed
                    a.at = Date()
                    self.anchor = a
                }
            }
        }
    }

    // MARK: - Ticker

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        guard let a = anchor else { return }
        let ideal = a.elapsed + a.rate * Date().timeIntervalSince(a.at)
        let clampedIdeal = state.duration.map { min(ideal, $0) } ?? ideal
        let delta = clampedIdeal - displayedElapsed

        if abs(delta) > snapThreshold {
            // Scrub or stale anchor — trust reality.
            displayedElapsed = clampedIdeal
        } else if delta < 0 {
            // Small backward correction — never regress. Hold display; the
            // authoritative "ideal" will catch up as time advances (or not,
            // if paused, in which case holding at the slightly-later value
            // is harmless).
            // No-op.
        } else {
            // Advance locally at the authoritative rate, but don't run far
            // ahead of ideal.
            let step = a.rate * tickInterval
            var next = displayedElapsed + step
            if next > clampedIdeal + forwardOvershootAllowed {
                next = clampedIdeal + forwardOvershootAllowed
            }
            displayedElapsed = next
        }

        // Publish the displayed value to the UI.
        if state.elapsed != displayedElapsed {
            var np = state
            np.elapsed = displayedElapsed
            state = np
        }
    }

    // MARK: - Commands (with optimistic local update)

    func send(_ cmd: MRCommand) {
        applyOptimistic(for: cmd)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: perlPath)
        p.arguments = [scriptURL.path, frameworkURL.path, "send", String(cmd.rawValue)]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do { try p.run() } catch {
            NSLog("[macpod] send failed: %@", String(describing: error))
        }
    }

    private func applyOptimistic(for cmd: MRCommand) {
        // Mirror the expected rate/playing change immediately so the UI feels
        // snappy and the subsequent authoritative event lands inside our
        // deadband (invisible correction).
        let current: Double = {
            guard let a = anchor else { return displayedElapsed }
            return a.elapsed + a.rate * Date().timeIntervalSince(a.at)
        }()

        func expect(_ playing: Bool) {
            expectedPlaying = playing
            expectedUntil = Date().addingTimeInterval(expectationWindow)
        }

        switch cmd {
        case .pause, .stop:
            anchor = Anchor(elapsed: current, at: Date(), rate: 0)
            displayedElapsed = current
            expect(false)
            var np = state; np.isPlaying = false; np.elapsed = displayedElapsed
            state = np
        case .play:
            anchor = Anchor(elapsed: current, at: Date(), rate: 1)
            displayedElapsed = current
            expect(true)
            var np = state; np.isPlaying = true; np.elapsed = displayedElapsed
            state = np
        case .togglePlayPause:
            let nowPlaying = !state.isPlaying
            anchor = Anchor(elapsed: current, at: Date(), rate: nowPlaying ? 1 : 0)
            displayedElapsed = current
            expect(nowPlaying)
            var np = state; np.isPlaying = nowPlaying; np.elapsed = displayedElapsed
            state = np
        case .nextTrack, .previousTrack:
            // The authoritative event will carry the new track's elapsed.
            // Don't predict — just wait for it.
            break
        }
    }
}
