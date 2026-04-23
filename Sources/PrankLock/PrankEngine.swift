import AppKit
import Carbon
import Combine
import SwiftUI

/// Coordinates all prank behaviors while the screen is locked.
@MainActor
final class PrankEngine: ObservableObject {
    private let store: PrankStore
    private var eventMonitors: [Any] = []
    private var timers: [Timer] = []
    private var overlayWindow: NSWindow?

    init(store: PrankStore) {
        self.store = store
    }

    // MARK: - Lifecycle

    func start() {
        showOverlay()
        installEventMonitors()
        scheduleRepeatingGags()
    }

    func stop() {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors = []
        timers.forEach { $0.invalidate() }
        timers = []
        overlayWindow?.close()
        overlayWindow = nil
    }

    // MARK: - Overlay (always on top warning banner)

    private func showOverlay() {
        guard overlayWindow == nil else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let bannerHeight: CGFloat = 60
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - bannerHeight,
            width: screen.frame.width,
            height: bannerHeight
        )
        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver
        win.backgroundColor = NSColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 0.92)
        win.isOpaque = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let label = NSTextField(labelWithString: "🔒  PrankLock Active — " + store.randomMessage())
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 0, width: frame.width, height: bannerHeight)
        win.contentView?.addSubview(label)
        win.orderFront(nil)
        overlayWindow = win
    }

    // MARK: - Event monitors

    private func installEventMonitors() {
        // Block mouse clicks on all apps
        let clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleClick(event)
        }
        if let m = clickMonitor { eventMonitors.append(m) }

        if store.intensity == .chaos || store.intensity == .evil {
            // Mouse-move monitor to flee cursor
            let moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                self?.fleeCursor()
            }
            if let m = moveMonitor { eventMonitors.append(m) }

            // Keyboard scramble
            let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
                self?.scrambleResponse()
            }
            if let m = keyMonitor { eventMonitors.append(m) }
        }
    }

    // MARK: - Gag dispatchers

    private func handleClick(_ event: NSEvent) {
        store.logAttempt("Mouse click detected")
        if !store.silentMode { Sounds.play(.denied) }
        showToast(store.randomMessage())

        if store.intensity == .chaos || store.intensity == .evil {
            minimizeFrontWindow()
        }
        if store.intensity == .evil {
            teleportRandomWindow()
        }
    }

    private func fleeCursor() {
        guard store.intensity != .light else { return }
        let screen = NSScreen.main?.frame ?? .zero
        let newX = CGFloat.random(in: screen.minX + 50 ... screen.maxX - 50)
        let newY = CGFloat.random(in: screen.minY + 50 ... screen.maxY - 50)
        CGWarpMouseCursorPosition(CGPoint(x: newX, y: newY))
    }

    private func scrambleResponse() {
        // Type a random "scrambled" replacement using AppleScript
        let junk = ["…", "¿", "∑", "®", "†", "¥", "ø", "π"]
        guard let char = junk.randomElement() else { return }
        // Use a delay so the real keystroke lands first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let src = CGEventSource(stateID: .hidSystemState)
            var uchar = UniChar(truncatingIfNeeded: char.unicodeScalars.first!.value)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &uchar)
            down?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Repeating gags

    private func scheduleRepeatingGags() {
        // Random toast every 30-60s
        let toastTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 30...60), repeats: true) { [weak self] _ in
            guard let self, self.store.isLocked else { return }
            Task { @MainActor in self.showToast(self.store.randomMessage()) }
        }
        timers.append(toastTimer)

        if store.intensity == .chaos || store.intensity == .evil {
            // Bounce windows every 45s
            let bounceTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
                guard let self, self.store.isLocked else { return }
                Task { @MainActor in self.bounceWindows() }
            }
            timers.append(bounceTimer)
        }

        if store.intensity == .evil {
            // Fake "BSOD" loading screen every 2 minutes
            let bsodTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
                guard let self, self.store.isLocked else { return }
                Task { @MainActor in self.showFakeLoadingScreen() }
            }
            timers.append(bsodTimer)
        }
    }

    // MARK: - Individual gags

    func showToast(_ message: String) {
        guard let screen = NSScreen.main else { return }
        let w: CGFloat = 380
        let h: CGFloat = 64
        let frame = NSRect(
            x: screen.frame.midX - w / 2,
            y: screen.frame.minY + 80,
            width: w,
            height: h
        )
        let toast = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        toast.level = .floating
        toast.backgroundColor = .clear
        toast.isOpaque = false
        toast.collectionBehavior = [.canJoinAllSpaces]

        let view = NSHostingView(rootView: ToastView(message: message))
        view.frame = NSRect(origin: .zero, size: frame.size)
        toast.contentView = view
        toast.orderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { toast.close() }
    }

    private func minimizeFrontWindow() {
        NSWorkspace.shared.frontmostApplication?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let win = NSApplication.shared.windows.first(where: { $0.isVisible && !$0.isMiniaturized }) {
                win.miniaturize(nil)
            }
        }
    }

    private func teleportRandomWindow() {
        guard let screen = NSScreen.main else { return }
        let wins = NSApplication.shared.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }
        guard let win = wins.randomElement() else { return }
        let newX = CGFloat.random(in: 0...max(0, screen.visibleFrame.width - win.frame.width))
        let newY = CGFloat.random(in: 0...max(0, screen.visibleFrame.height - win.frame.height))
        win.setFrameOrigin(NSPoint(x: newX, y: newY))
    }

    private func bounceWindows() {
        guard let screen = NSScreen.main else { return }
        let wins = NSApplication.shared.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }
        for win in wins {
            let x = CGFloat.random(in: 0...max(0, screen.visibleFrame.width - win.frame.width))
            let y = CGFloat.random(in: 0...max(0, screen.visibleFrame.height - win.frame.height))
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                win.animator().setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }

    private func showFakeLoadingScreen() {
        guard let screen = NSScreen.main else { return }
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.contentView = NSHostingView(rootView: FakeLoadingView())
        win.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { win.close() }
    }
}
