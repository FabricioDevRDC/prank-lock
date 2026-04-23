import AppKit
import Combine

/// Fires a callback when the Mac has been idle longer than `threshold` seconds.
final class InactivityWatcher {
    private var timer: Timer?
    private let threshold: TimeInterval
    private let onIdle: () -> Void

    init(threshold: TimeInterval, onIdle: @escaping () -> Void) {
        self.threshold = threshold
        self.onIdle = onIdle
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let idleKey = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let since = min(idle, idleKey)
        if since >= threshold {
            DispatchQueue.main.async { self.onIdle() }
        }
    }
}
