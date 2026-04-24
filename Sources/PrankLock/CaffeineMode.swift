import AppKit

/// Moves the cursor by 1px every 55s to prevent the screen from sleeping.
/// Completely independent of PrankLock — works whether locked or not.
@MainActor
final class CaffeineMode {
    static let shared = CaffeineMode()
    private(set) var isActive = false
    private var timer: Timer?
    private var nudgeDirection = true

    private init() {}

    func toggle() {
        isActive ? stop() : start()
    }

    func start() {
        guard !isActive else { return }
        isActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 55, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.nudge() }
        }
    }

    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }

    private func nudge() {
        let pos = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        // Flip to CG coords and move 1px back and forth
        let cgY = screen.frame.height - pos.y
        let offset: CGFloat = nudgeDirection ? 1 : -1
        nudgeDirection.toggle()
        CGWarpMouseCursorPosition(CGPoint(x: pos.x + offset, y: cgY))
    }
}
