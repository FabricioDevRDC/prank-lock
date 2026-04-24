import AppKit
import Combine

@MainActor
final class LockCoordinator {
    private let store: PrankStore
    private var engine: PrankEngine?
    private var blocker: AppBlocker?
    private var inactivityWatcher: InactivityWatcher?
    private var comboWatcher: ComboUnlockWatcher?
    private var cancellables = Set<AnyCancellable>()
    private var unlockWindow: NSWindow?

    init(store: PrankStore) {
        self.store = store
        store.$isLocked.sink { [weak self] locked in
            if locked { self?.didLock() } else { self?.didUnlock() }
        }.store(in: &cancellables)
    }

    func bringUnlockWindowForward() {
        if let win = unlockWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func didLock() {
        let e = PrankEngine(store: store)

        // Combo watcher unlocks without any UI — just hold the secret keys 2 sec
        let cw = ComboUnlockWatcher(store: store) { [weak self] in
            self?.store.unlockWithCombo()
        }
        cw.start()
        e.comboWatcher = cw
        e.start()
        comboWatcher = cw
        engine = e

        let b = AppBlocker(store: store)
        b.start()
        blocker = b

        if store.lockAfterSeconds > 0 {
            let w = InactivityWatcher(threshold: TimeInterval(store.lockAfterSeconds)) { [weak self] in
                guard let self, !self.store.isLocked else { return }
                self.store.lock(with: self.store.unlockCombo)
            }
            w.start()
            inactivityWatcher = w
        }

        if store.alsoLockScreen { store.triggerRealLock() }
        showUnlockHint()
    }

    private func didUnlock() {
        engine?.stop()
        engine = nil
        comboWatcher?.stop()
        comboWatcher = nil
        blocker?.stop()
        blocker = nil
        inactivityWatcher?.stop()
        inactivityWatcher = nil
        unlockWindow?.close()
        unlockWindow = nil
        (NSApp.delegate as? AppDelegate)?.handleUnlock()
    }

    // Tiny bottom-corner hint visible only to the owner (no password needed)
    private func showUnlockHint() {
        guard let screen = NSScreen.main else { return }
        let combo = store.unlockCombo.symbols
        let msg = "Hold \(combo) for 2 sec to unlock"

        let w: CGFloat = 260, h: CGFloat = 36
        let frame = NSRect(
            x: screen.visibleFrame.minX + 12,
            y: screen.visibleFrame.minY + 12,
            width: w, height: h
        )
        let win = NSWindow(contentRect: frame, styleMask: [.borderless],
                           backing: .buffered, defer: false)
        win.level = .floating
        win.backgroundColor = .clear
        win.isOpaque = false
        win.isReleasedWhenClosed = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces]

        let label = NSTextField(labelWithString: "🔒 " + msg)
        label.textColor = NSColor.white.withAlphaComponent(0.5)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 0, width: w, height: h)
        win.contentView?.addSubview(label)
        win.orderFront(nil)
        unlockWindow = win
    }
}
