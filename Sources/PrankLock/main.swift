import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var lockWindow: NSWindow?
    var store: PrankStore!
    var coordinator: LockCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = PrankStore()
        NSApp.setActivationPolicy(.accessory)
        coordinator = LockCoordinator(store: store)
        buildMenuBar()
    }

    func buildMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem?.button {
            btn.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "PrankLock")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Activate PrankLock…", action: #selector(openActivate), keyEquivalent: "L"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit PrankLock", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    @objc func openActivate() {
        let win = makeHostingWindow(ActivateView(store: store), size: CGSize(width: 420, height: 320))
        win.title = "Activate PrankLock"
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        lockWindow = win
    }

    @objc func openPrefs() {
        let win = makeHostingWindow(PreferencesView(store: store), size: CGSize(width: 480, height: 540))
        win.title = "PrankLock Preferences"
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() { NSApp.terminate(nil) }
}

func makeHostingWindow<V: View>(_ view: V, size: CGSize) -> NSWindow {
    let win = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    win.center()
    win.contentView = NSHostingView(rootView: view)
    return win
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
