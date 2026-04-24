import AppKit
import SwiftUI
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var store: PrankStore!
    var coordinator: LockCoordinator?
    var openWindows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = PrankStore()
        NSApp.setActivationPolicy(.accessory)
        coordinator = LockCoordinator(store: store)
        buildMenuBar()
        requestAccessibilityPermission()
    }

    // MARK: - Accessibility

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Menu bar

    func buildMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "lock.fill",
                                            accessibilityDescription: "PrankLock")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Activate PrankLock…", action: #selector(openActivate), keyEquivalent: "L"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ","))
        menu.addItem(.separator())
        let caffeineItem = NSMenuItem(title: "☕ Keep Awake", action: #selector(toggleCaffeine), keyEquivalent: "")
        caffeineItem.target = self
        menu.addItem(caffeineItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit PrankLock", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { if $0.target == nil { $0.target = self } }
        statusItem?.menu = menu
    }

    @objc func toggleCaffeine() {
        MainActor.assumeIsolated {
            CaffeineMode.shared.toggle()
            guard let menu = statusItem?.menu else { return }
            for item in menu.items where item.action == #selector(toggleCaffeine) {
                item.title = CaffeineMode.shared.isActive ? "☕ Keep Awake  ✓" : "☕ Keep Awake"
            }
        }
    }

    func setMenuBarVisible(_ visible: Bool) {
        if visible { if statusItem == nil { buildMenuBar() } }
        else { statusItem = nil }
    }

    // MARK: - Windows

    @objc func openActivate() {
        let win = makeHostingWindow(
            ActivateView(store: store,
                         onActivated: { [weak self] in self?.setMenuBarVisible(false) },
                         onDismiss:   { NSApp.keyWindow?.close() }),
            size: CGSize(width: 440, height: 400),
            title: "Activate PrankLock"
        )
        present(win)
    }

    @objc func openPrefs() {
        let win = makeHostingWindow(
            PreferencesView(store: store),
            size: CGSize(width: 480, height: 540),
            title: "PrankLock Preferences"
        )
        present(win)
    }

    @objc func quit() { NSApp.terminate(nil) }

    func handleUnlock() { setMenuBarVisible(true) }

    private func present(_ win: NSWindow) {
        openWindows.removeAll { !$0.isVisible }
        openWindows.append(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Window factory

func makeHostingWindow<V: View>(_ view: V, size: CGSize, title: String = "") -> NSWindow {
    let win = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    win.title = title
    win.center()
    win.contentView = NSHostingView(rootView: view)
    win.isReleasedWhenClosed = false
    return win
}

// MARK: - Entry point

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
