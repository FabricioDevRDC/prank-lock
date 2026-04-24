import Foundation
import AppKit
import Combine

// MARK: - Intensity

enum PrankIntensity: String, CaseIterable, Codable, Identifiable {
    case light = "Light"
    case chaos = "Chaos"
    case evil  = "Evil"
    var id: String { rawValue }

    var description: String {
        switch self {
        case .light: return "Gentle — warnings + blocked apps"
        case .chaos: return "Chaos — cursor flee, windows bounce"
        case .evil:  return "Evil — everything + fake OS update screen"
        }
    }
    var emoji: String {
        switch self {
        case .light: return "😏"
        case .chaos: return "🌀"
        case .evil:  return "😈"
        }
    }
}

// MARK: - Unlock Combo

struct UnlockCombo {
    var flags: NSEvent.ModifierFlags

    static let empty = UnlockCombo(flags: [])

    var isEmpty: Bool { relevant.isEmpty }

    var relevant: NSEvent.ModifierFlags {
        flags.intersection([.shift, .control, .option, .command])
    }

    var displayString: String {
        guard !relevant.isEmpty else { return "—" }
        var parts: [String] = []
        if relevant.contains(.control) { parts.append("⌃ Control") }
        if relevant.contains(.option)  { parts.append("⌥ Option") }
        if relevant.contains(.command) { parts.append("⌘ Command") }
        if relevant.contains(.shift)   { parts.append("⇧ Shift") }
        return parts.joined(separator: " + ")
    }

    var symbols: String {
        var s = ""
        if relevant.contains(.control) { s += "⌃" }
        if relevant.contains(.option)  { s += "⌥" }
        if relevant.contains(.command) { s += "⌘" }
        if relevant.contains(.shift)   { s += "⇧" }
        return s
    }

    var rawValue: UInt { relevant.rawValue }
    init(flags: NSEvent.ModifierFlags) { self.flags = flags }
    init(rawValue: UInt) { self.flags = NSEvent.ModifierFlags(rawValue: rawValue) }
}

// MARK: - Attempt log

struct AttemptEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var action: String
}

// MARK: - UserDefaults keys

private enum K {
    static let intensity      = "pl.intensity"
    static let messages       = "pl.messages"
    static let blockedApps    = "pl.blockedApps"
    static let silentMode     = "pl.silentMode"
    static let lockAfter      = "pl.lockAfterSeconds"
    static let alsoLockScreen = "pl.alsoLockScreen"
    static let combo          = "pl.combo"
    static let soundDenied    = "pl.sound.denied"
    static let soundAlert     = "pl.sound.alert"
    static let soundBounce    = "pl.sound.bounce"
}

// MARK: - Store

@MainActor
final class PrankStore: ObservableObject {
    @Published var intensity: PrankIntensity
    @Published var customMessages: [String]
    @Published var blockedAppBundleIDs: [String]
    @Published var silentMode: Bool
    @Published var lockAfterSeconds: Int
    @Published var alsoLockScreen: Bool

    /// Sound IDs (filename without extension) chosen per slot. Empty = no sound.
    @Published var soundDenied: String   // on click / blocked app
    @Published var soundAlert: String    // on keyboard
    @Published var soundBounce: String   // on window bounce

    /// All sounds found on the system — populated once at init.
    let availableSounds: [SystemSound]

    @Published var isLocked = false
    @Published var attemptLog: [AttemptEntry] = []

    private let ud = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    init() {
        availableSounds = SoundScanner.scan()

        intensity        = PrankIntensity(rawValue: UserDefaults.standard.string(forKey: K.intensity) ?? "") ?? .chaos
        customMessages   = UserDefaults.standard.stringArray(forKey: K.messages) ?? [
            "Nice try 👀", "Step away from this Mac",
            "Donuts denied 🍩", "🚨 Boss is watching", "Access denied, pal",
        ]
        blockedAppBundleIDs = UserDefaults.standard.stringArray(forKey: K.blockedApps) ?? []
        silentMode       = UserDefaults.standard.bool(forKey: K.silentMode)
        lockAfterSeconds = UserDefaults.standard.integer(forKey: K.lockAfter)
        alsoLockScreen   = UserDefaults.standard.bool(forKey: K.alsoLockScreen)
        soundDenied      = UserDefaults.standard.string(forKey: K.soundDenied)  ?? "Basso"
        soundAlert       = UserDefaults.standard.string(forKey: K.soundAlert)   ?? "Sosumi"
        soundBounce      = UserDefaults.standard.string(forKey: K.soundBounce)  ?? "Funk"

        $intensity          .dropFirst().sink { UserDefaults.standard.set($0.rawValue, forKey: K.intensity) }   .store(in: &cancellables)
        $customMessages     .dropFirst().sink { UserDefaults.standard.set($0, forKey: K.messages) }             .store(in: &cancellables)
        $blockedAppBundleIDs.dropFirst().sink { UserDefaults.standard.set($0, forKey: K.blockedApps) }          .store(in: &cancellables)
        $silentMode         .dropFirst().sink { UserDefaults.standard.set($0, forKey: K.silentMode) }           .store(in: &cancellables)
        $lockAfterSeconds   .dropFirst().sink { UserDefaults.standard.set($0, forKey: K.lockAfter) }            .store(in: &cancellables)
        $alsoLockScreen     .dropFirst().sink { UserDefaults.standard.set($0, forKey: K.alsoLockScreen) }       .store(in: &cancellables)
        $soundDenied        .dropFirst().sink { UserDefaults.standard.set($0, forKey: K.soundDenied) }          .store(in: &cancellables)
        $soundAlert         .dropFirst().sink { UserDefaults.standard.set($0, forKey: K.soundAlert) }           .store(in: &cancellables)
        $soundBounce        .dropFirst().sink { UserDefaults.standard.set($0, forKey: K.soundBounce) }          .store(in: &cancellables)
    }

    // MARK: - Combo

    var unlockCombo: UnlockCombo {
        get { UnlockCombo(rawValue: ud.object(forKey: K.combo) as? UInt ?? 0) }
        set { ud.set(newValue.rawValue, forKey: K.combo) }
    }

    // MARK: - Lock / Unlock

    func lock(with combo: UnlockCombo) {
        guard !combo.isEmpty else { return }
        unlockCombo = combo
        isLocked = true
    }

    func unlockWithCombo() {
        isLocked = false
        logAttempt("Unlocked by owner")
    }

    // MARK: - Logging

    func logAttempt(_ action: String) {
        attemptLog.insert(AttemptEntry(date: Date(), action: action), at: 0)
        if attemptLog.count > 200 { attemptLog.removeLast() }
    }

    func randomMessage() -> String {
        customMessages.randomElement() ?? "Nice try 👀"
    }

    // MARK: - macOS screen lock

    func triggerRealLock() {
        logAttempt("macOS screen lock triggered")
        let script = "tell application \"System Events\" to key code 12 using {command down, control down}"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }
}
