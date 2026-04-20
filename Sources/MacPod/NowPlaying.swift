import Foundation
import AppKit

struct NowPlaying: Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var artwork: NSImage?
    var duration: Double?
    var elapsed: Double?
    var isPlaying: Bool
    var bundleIdentifier: String?
    var trackNumber: Int?

    static let empty = NowPlaying(isPlaying: false)
}

enum MRCommand: Int {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case stop = 3
    case nextTrack = 4
    case previousTrack = 5
}
