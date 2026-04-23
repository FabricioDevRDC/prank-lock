import AppKit
import Combine

/// Owns the PrankEngine and supporting services; reacts to store.isLocked changes.
@MainActor
final class LockCoordinator {
    private let store: PrankStore
    private var engine: PrankEngine?
    private var blocker: AppBlocker?
    private var inactivityWatcher: InactivityWatcher?
    private var cancellables = Set<AnyCancellable>()
    private var unlockWindow: NSWindow?

    init(store: PrankStore) {
        self.store = store
        store.$isLocked.sink { [weak self] locked in
            if locked { self?.didLock() } else { self?.didUnlock() }
        }.store(in: &cancellables)
    }

    private func didLock() {
        let e = PrankEngine(store: store)
        e.start()
        engine = e

        let b = AppBlocker(store: store)
        b.start()
        blocker = b

        if store.lockAfterSeconds > 0 {
            let watcher = InactivityWatcher(threshold: TimeInterval(store.lockAfterSeconds)) { [weak self] in
                guard let self, !self.store.isLocked else { return }
                self.store.lock(with: self.store.password)
            }
            watcher.start()
            inactivityWatcher = watcher
        }

        showUnlockWindow()
    }

    private func didUnlock() {
        engine?.stop()
        engine = nil
        blocker?.stop()
        blocker = nil
        inactivityWatcher?.stop()
        inactivityWatcher = nil
        unlockWindow?.close()
        unlockWindow = nil
    }

    private func showUnlockWindow() {
        let win = makeHostingWindow(UnlockView(store: store), size: CGSize(width: 340, height: 320))
        win.title = "PrankLock"
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces]
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        unlockWindow = win
    }
}
