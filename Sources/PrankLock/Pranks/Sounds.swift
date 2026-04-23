import AppKit

enum SoundEffect: String, CaseIterable {
    case denied    = "Basso"
    case alert     = "Sosumi"
    case tada      = "Glass"
    case wilhelm   = "Funk"
    case airhorn   = "Blow"
}

enum Sounds {
    static func play(_ effect: SoundEffect) {
        NSSound(named: NSSound.Name(effect.rawValue))?.play()
    }
}
