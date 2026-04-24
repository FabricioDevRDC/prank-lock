import AppKit

/// Watches modifier key state globally. When the secret combo is held for
/// `holdDuration` seconds it calls `onUnlock`. While the combo is held,
/// it also signals `isHoldingCombo` so the engine can pause cursor flee.
@MainActor
final class ComboUnlockWatcher {
    private(set) var isHoldingCombo = false

    private let store: PrankStore
    private let holdDuration: TimeInterval = 2.0
    private var monitor: Any?
    private var holdStart: Date?
    private var checkTimer: Timer?
    private var onUnlock: (() -> Void)?

    init(store: PrankStore, onUnlock: @escaping () -> Void) {
        self.store = store
        self.onUnlock = onUnlock
    }

    func start() {
        // flagsChanged fires on the private NSEvent thread — hop to main
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async { self?.handleFlags(event.modifierFlags) }
        }
        // Poll every 0.1s to detect sustained hold
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        checkTimer?.invalidate()
        checkTimer = nil
        holdStart = nil
        isHoldingCombo = false
    }

    // MARK: - Private

    private func handleFlags(_ flags: NSEvent.ModifierFlags) {
        let combo = store.unlockCombo
        let current = flags.intersection([.shift, .control, .option, .command])
        let required = combo.relevant

        if current == required && !required.isEmpty {
            if holdStart == nil { holdStart = Date() }
            isHoldingCombo = true
        } else {
            holdStart = nil
            isHoldingCombo = false
        }
    }

    private func tick() {
        guard let start = holdStart else { return }
        if Date().timeIntervalSince(start) >= holdDuration {
            holdStart = nil
            isHoldingCombo = false
            onUnlock?()
        }
    }
}
