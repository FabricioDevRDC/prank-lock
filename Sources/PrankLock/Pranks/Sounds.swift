import AppKit

// MARK: - System sound scanner

struct SystemSound: Identifiable, Hashable {
    let id: String      // filename without extension e.g. "Basso"
    let url: URL
    var displayName: String { id }
}

enum SoundScanner {
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

    // Keep strong refs so NSSound is alive while playing
    private var playing: [NSSound] = []

    private init() {}

    func play(named soundID: String, from library: [SystemSound]) {
        guard !soundID.isEmpty else { return }
        guard let sound = library.first(where: { $0.id == soundID }) else { return }
        play(url: sound.url)
    }

    func play(url: URL) {
        // Remove finished sounds
        playing.removeAll { !$0.isPlaying }

        // Load by file path — this works reliably in a non-sandboxed background app.
        // NSSound(named:) requires a proper CoreAudio session that menu-bar apps don't get.
        guard let sound = NSSound(contentsOf: url, byReference: false) else { return }
        sound.volume = 1.0
        sound.play()
        playing.append(sound)
    }
}
