import AVFoundation
import AppKit

// MARK: - System sound scanner

struct SystemSound: Identifiable, Hashable {
    let id: String      // filename without extension, e.g. "Basso"
    let url: URL

    var displayName: String { id }
}

enum SoundScanner {
    /// All directories macOS uses for system alert sounds.
    private static let searchPaths: [String] = [
        "/System/Library/Sounds",
        "/Library/Sounds",
        NSString("~/Library/Sounds").expandingTildeInPath,
    ]

    static func scan() -> [SystemSound] {
        var found: [SystemSound] = []
        let fm = FileManager.default
        for dir in searchPaths {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items.sorted() {
                let url = URL(fileURLWithPath: dir).appendingPathComponent(item)
                let ext = url.pathExtension.lowercased()
                guard ["aiff", "aif", "wav", "mp3", "m4a", "caf"].contains(ext) else { continue }
                let name = url.deletingPathExtension().lastPathComponent
                if !found.contains(where: { $0.id == name }) {
                    found.append(SystemSound(id: name, url: url))
                }
            }
        }
        return found
    }
}

// MARK: - Player

final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [AVAudioPlayer] = []

    private init() {}

    func play(url: URL) {
        // Clean up finished players
        players.removeAll { !$0.isPlaying }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 1.0
            p.prepareToPlay()
            p.play()
            players.append(p)   // keep strong ref until playback ends
        } catch {
            // Fallback to NSSound if AVAudioPlayer fails for any reason
            NSSound(contentsOf: url, byReference: false)?.play()
        }
    }

    func play(named soundID: String, from library: [SystemSound]) {
        guard let sound = library.first(where: { $0.id == soundID }) else { return }
        play(url: sound.url)
    }
}

// MARK: - Legacy enum shim (used internally in PrankEngine)

enum SoundSlot: String, CaseIterable {
    case denied   // played on click / block
    case alert    // played on keyboard
    case bounce   // played on window bounce
}
