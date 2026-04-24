import AppKit

/// Watches for apps launching or being activated and force-quits any on the blocklist.
final class AppBlocker {
    private var observers: [Any] = []
    private let store: PrankStore

    init(store: PrankStore) {
        self.store = store
    }

    func start() {
        // Catch both: launch (fresh open) and activate (switch to already-open app)
        let names: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ]
        for name in names {
            let obs = NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication else { return }
                Task { @MainActor [weak self] in self?.handle(app) }
            }
            observers.append(obs)
        }
    }

    func stop() {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
    }

    // MARK: - Private

    @MainActor
    private func handle(_ app: NSRunningApplication) {
        guard store.isLocked else { return }
        guard store.blockedAppBundleIDs.contains(app.bundleIdentifier ?? "") else { return }
        store.logAttempt("Blocked: \(app.localizedName ?? app.bundleIdentifier ?? "unknown")")
        app.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !app.isTerminated { app.forceTerminate() }
        }
    }
}
