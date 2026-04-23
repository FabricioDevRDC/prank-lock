import Foundation
import Combine
import CoreGraphics

// MARK: - Intensity

enum PrankIntensity: String, CaseIterable, Codable, Identifiable {
    case light = "Light"
    case chaos = "Chaos"
    case evil  = "Evil"
    var id: String { rawValue }

    var description: String {
        switch self {
        case .light: return "Gentle trolling — warnings + blocked apps"
        case .chaos: return "Full chaos — cursor flee, windows bounce, scrambled keys"
        case .evil:  return "Maximum prank — everything + fake OS crash screen"
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

// MARK: - Attempt Log

struct AttemptEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var action: String
}

// MARK: - Store

@MainActor
final class PrankStore: ObservableObject {
    @Published var isLocked = false
    @Published var intensity: PrankIntensity = .chaos
    @Published var customMessages: [String] = [
        "Nice try 👀",
        "Step away from this Mac",
        "Donuts denied 🍩",
        "🚨 Boss is watching",
        "Access denied, pal",
    ]
    @Published var selectedMessages: Set<String> = []
    @Published var blockedAppBundleIDs: [String] = []
    @Published var silentMode = false
    @Published var snapshotOnFail = false
    @Published var lockAfterSeconds: Int = 0     // 0 = disabled
    @Published var realLockAfterFailures: Int = 0 // 0 = disabled
    @Published var attemptLog: [AttemptEntry] = []
    @Published var hotkey: String = "⌃⌥⌘L"
    @Published var failureCount = 0

    private let passwordKey = "pranklock.password"

    var password: String {
        get { UserDefaults.standard.string(forKey: passwordKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: passwordKey) }
    }

    func lock(with pin: String) {
        guard !pin.isEmpty else { return }
        password = pin
        failureCount = 0
        isLocked = true
    }

    func unlock(with attempt: String) -> Bool {
        if attempt == password {
            isLocked = false
            failureCount = 0
            return true
        }
        failureCount += 1
        logAttempt("Wrong password attempt #\(failureCount)")
        if realLockAfterFailures > 0, failureCount >= realLockAfterFailures {
            triggerRealLock()
        }
        return false
    }

    func logAttempt(_ action: String) {
        let entry = AttemptEntry(date: Date(), action: action)
        attemptLog.insert(entry, at: 0)
        if attemptLog.count > 200 { attemptLog.removeLast() }
    }

    func randomMessage() -> String {
        let pool = selectedMessages.isEmpty ? Set(customMessages) : selectedMessages
        return pool.randomElement() ?? "Nice try 👀"
    }

    private func triggerRealLock() {
        logAttempt("Real lock triggered after \(failureCount) failed attempts")
        let src = CGEventSource(stateID: .hidSystemState)
        // Send Command+Control+Q to trigger macOS lock screen
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x0C, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x0C, keyDown: false)
        keyDown?.flags = [.maskCommand, .maskControl]
        keyUp?.flags   = [.maskCommand, .maskControl]
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
