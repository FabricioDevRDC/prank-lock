import AppKit
import Combine
import SwiftUI

@MainActor
final class PrankEngine {
    private let store: PrankStore
    var comboWatcher: ComboUnlockWatcher?   // set by LockCoordinator
    private var eventMonitors: [Any] = []
    private var timers: [Timer] = []
    private var overlayWindow: NSWindow?
    // Strong refs so ARC doesn't free windows before we close them
    private var activeToasts: [NSWindow] = []
    private var fakeLoadingWindow: NSWindow?
    private let dockShield = DockShieldManager()

    init(store: PrankStore) {
        self.store = store
    }

    // MARK: - Lifecycle

    func start() {
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
        activeToasts.forEach { $0.close() }
        activeToasts = []
        fakeLoadingWindow?.close()
        fakeLoadingWindow = nil
        dockShield.removeAllShields()
    }

    // MARK: - Overlay (Evil mode only — stealth otherwise)

    private func showOverlay() {
        guard store.intensity == .evil else { return }
        guard overlayWindow == nil else { return }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let h: CGFloat = 60
        let frame = NSRect(x: screen.frame.minX, y: screen.frame.maxY - h,
                           width: screen.frame.width, height: h)
        let win = NSWindow(contentRect: frame, styleMask: [.borderless],
                           backing: .buffered, defer: false)
        win.level = .screenSaver
        win.backgroundColor = NSColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 0.92)
        win.isOpaque = false
        win.ignoresMouseEvents = true
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let label = NSTextField(labelWithString: "🔒  PrankLock Active — " + store.randomMessage())
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 0, width: frame.width, height: h)
        win.contentView?.addSubview(label)
        win.orderFront(nil)
        overlayWindow = win
    }

    // MARK: - Event monitors
    // Global monitors fire on a PRIVATE background thread — always hop to main
    // before touching any state or UI.

    private func installEventMonitors() {
        // Clicks only fire pranks when the clicked window belongs to a BLOCKED app.
        // For non-blocked apps the intruder can use them normally — we just log it.
        let clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            DispatchQueue.main.async { self?.handleClick(event) }
        }
        if let m = clickMonitor { eventMonitors.append(m) }

        guard store.intensity == .chaos || store.intensity == .evil else { return }

        // Cursor flee + dock shield on mouse move
        let moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            DispatchQueue.main.async {
                guard let self else { return }
                self.fleeCursorThrottled()
                if self.store.intensity == .evil && !self.store.blockedAppBundleIDs.isEmpty {
                    // CG cursor position has top-left origin; convert to AppKit bottom-left
                    let cgPos = NSEvent.mouseLocation  // already in AppKit screen coords
                    self.dockShield.handleMouseMove(cursor: cgPos, blockedBundleIDs: self.store.blockedAppBundleIDs)
                }
            }
        }
        if let m = moveMonitor { eventMonitors.append(m) }

        // Keyboard: toast + clipboard hijack on every keypress (throttled)
        let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            DispatchQueue.main.async {
                self?.scrambleResponseThrottled()
                self?.hijackClipboardThrottled()
            }
        }
        if let m = keyMonitor { eventMonitors.append(m) }
    }

    // MARK: - Gag dispatchers

    // MARK: - Click handler

    private func handleClick(_ event: NSEvent) {
        showOverlay()
        store.logAttempt("Click detected")
        playSlot(store.soundDenied)
        showToast(store.randomMessage())
        // Destructive gags only when clicking inside a blocked app
        guard isBlockedAppActive() else { return }
        if store.intensity == .chaos || store.intensity == .evil { minimizeFrontWindow() }
        if store.intensity == .evil { teleportRandomWindow() }
    }

    // MARK: - Throttled cursor flee (chaos/evil — blocked apps only)

    private var lastFlee: Date = .distantPast
    private func fleeCursorThrottled() {
        guard comboWatcher?.isHoldingCombo != true else { return }
        guard isBlockedAppActive() else { return }
        let now = Date()
        guard now.timeIntervalSince(lastFlee) >= 0.3 else { return }
        lastFlee = now
        let screen = NSScreen.main?.frame ?? .zero
        let x = CGFloat.random(in: screen.minX + 50 ... screen.maxX - 50)
        let y = CGFloat.random(in: screen.minY + 50 ... screen.maxY - 50)
        CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
    }

    // MARK: - Throttled keyboard response (chaos/evil — all apps)

    private var lastScramble: Date = .distantPast
    private func scrambleResponseThrottled() {
        showOverlay()
        let now = Date()
        guard now.timeIntervalSince(lastScramble) >= 1.5 else { return }
        lastScramble = now
        let msgs = ["⌨️ Nice typing, wrong computer", "🚫 Keyboard disabled",
                    "🍩 Donuts denied", "❌ Access denied"]
        playSlot(store.soundAlert)
        showToast(msgs.randomElement()!)
    }

    // MARK: - Clipboard hijack (chaos/evil — replaces clipboard text with a taunt)

    private var lastClipboard: Date = .distantPast
    func hijackClipboardThrottled() {
        let now = Date()
        guard now.timeIntervalSince(lastClipboard) >= 5 else { return }
        lastClipboard = now
        let taunts = [
            "🔒 Nice try. —PrankLock",
            "Your clipboard belongs to me now.",
            "Access denied. Go get your own Mac.",
            "This Mac is protected. Back off 👀",
            "Ctrl+V? Nope. 😈",
        ]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(taunts.randomElement()!, forType: .string)
        store.logAttempt("Clipboard hijacked")
    }

    // MARK: - Voice taunt via `say` (evil only)

    private var lastVoice: Date = .distantPast
    func voiceTauntThrottled() {
        let now = Date()
        guard now.timeIntervalSince(lastVoice) >= 30 else { return }
        lastVoice = now
        let lines = [
            "Hey, this is not your Mac",
            "Step away from the keyboard",
            "Password required",
            "Nice try, buddy",
        ]
        let line = lines.randomElement()!
        store.logAttempt("Voice taunt: \(line)")
        Process.launchedProcess(launchPath: "/usr/bin/say", arguments: ["-v", "Samantha", line])
    }

    // Returns true if frontmost app is in the blocked list, or if no list is configured.
    private func isBlockedAppActive() -> Bool {
        let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        return store.blockedAppBundleIDs.isEmpty || store.blockedAppBundleIDs.contains(frontID)
    }

    // MARK: - Repeating gags

    private func scheduleRepeatingGags() {
        let toastTimer = Timer.scheduledTimer(
            withTimeInterval: Double.random(in: 30...60), repeats: true
        ) { [weak self] _ in
            // Timer fires on main run loop — safe to hop via DispatchQueue to avoid
            // the Swift 6 @MainActor warning on the captured store property.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.store.isLocked else { return }
                self.showToast(self.store.randomMessage())
            }
        }
        timers.append(toastTimer)

        guard store.intensity == .chaos || store.intensity == .evil else { return }

        let bounceTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.store.isLocked else { return }
                self.bounceWindows()
            }
        }
        timers.append(bounceTimer)

        guard store.intensity == .evil else { return }

        // Mac speaks a taunt every ~45s in evil mode
        let voiceTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.store.isLocked else { return }
                self.voiceTauntThrottled()
            }
        }
        timers.append(voiceTimer)

        // Show fake loading screen 15s after locking, then every 60s
        let bsodTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.store.isLocked else { return }
                self.showFakeLoadingScreen()
                // Repeat every 60s after first show
                let repeat60 = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.store.isLocked else { return }
                        self.showFakeLoadingScreen()
                    }
                }
                self.timers.append(repeat60)
            }
        }
        timers.append(bsodTimer)
    }

    // MARK: - Individual gags

    func showToast(_ message: String) {
        guard let screen = NSScreen.main else { return }
        let w: CGFloat = 560, h: CGFloat = 110
        // Center horizontally, 35% from bottom so it's very visible
        let frame = NSRect(x: screen.frame.midX - w / 2,
                           y: screen.frame.minY + screen.frame.height * 0.35,
                           width: w, height: h)
        let toast = NSWindow(contentRect: frame, styleMask: [.borderless],
                             backing: .buffered, defer: false)
        toast.level = .floating
        toast.backgroundColor = .clear
        toast.isOpaque = false
        toast.isReleasedWhenClosed = false   // ARC owns it — no double-release
        toast.collectionBehavior = [.canJoinAllSpaces]
        toast.contentView = NSHostingView(rootView: ToastView(message: message))
        toast.orderFront(nil)

        activeToasts.append(toast)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self, weak toast] in
            toast?.close()
            self?.activeToasts.removeAll { $0 === toast }
        }
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
        let x = CGFloat.random(in: 0...max(0, screen.visibleFrame.width - win.frame.width))
        let y = CGFloat.random(in: 0...max(0, screen.visibleFrame.height - win.frame.height))
        win.setFrameOrigin(NSPoint(x: x, y: y))
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
        playSlot(store.soundBounce)
    }

    // MARK: - Sound helper

    private func playSlot(_ soundID: String) {
        guard !store.silentMode, !soundID.isEmpty else { return }
        SoundPlayer.shared.play(named: soundID, from: store.availableSounds)
    }

    private func showFakeLoadingScreen() {
        guard fakeLoadingWindow == nil, let screen = NSScreen.main else { return }
        let win = NSWindow(contentRect: screen.frame, styleMask: [.borderless],
                           backing: .buffered, defer: false)
        win.level = .screenSaver
        win.isReleasedWhenClosed = false   // ARC owns it
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.contentView = NSHostingView(rootView: FakeLoadingView())
        win.orderFront(nil)
        fakeLoadingWindow = win

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.fakeLoadingWindow?.close()
            self?.fakeLoadingWindow = nil
        }
    }
}
