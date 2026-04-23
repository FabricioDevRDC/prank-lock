import AppKit
import Combine

/// Watches for newly launched apps and force-quits any on the blocklist.
final class AppBlocker {
    private var workspaceObserver: Any?
    private let store: PrankStore

    init(store: PrankStore) {
        self.store = store
    }

    func start() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.store.isLocked else { return }
                if self.store.blockedAppBundleIDs.contains(app.bundleIdentifier ?? "") {
                    self.store.logAttempt("Blocked app launch: \(app.localizedName ?? app.bundleIdentifier ?? "unknown")")
                    app.forceTerminate()
                }
            }
        }
    }

    func stop() {
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
    }
}
