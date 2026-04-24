import AppKit
import AVFoundation

enum SoundEffect: CaseIterable {
    case denied
    case alert
    case glass
    case funk
    case blow

    fileprivate var systemName: String {
        switch self {
        case .denied: return "Basso"
        case .alert:  return "Sosumi"
        case .glass:  return "Glass"
        case .funk:   return "Funk"
        case .blow:   return "Blow"
        }
    }
}

enum Sounds {
    // Keep strong refs so sounds aren't released mid-playback
    private static var playing: [NSSound] = []

    static func play(_ effect: SoundEffect) {
        // Clean up finished sounds
        playing.removeAll { !$0.isPlaying }

        if let sound = NSSound(named: NSSound.Name(effect.systemName)) {
            sound.volume = 1.0
            sound.play()
            playing.append(sound)
        }
    }

    /// Say a phrase out loud using macOS text-to-speech.
    static func say(_ text: String) {
        let synth = NSSpeechSynthesizer()
        synth.startSpeaking(text)
        // NSSpeechSynthesizer manages its own lifetime while speaking
    }
}
