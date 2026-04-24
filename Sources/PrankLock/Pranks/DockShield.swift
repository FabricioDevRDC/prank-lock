import AppKit
import SwiftUI

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

// MARK: - Dock icon frame lookup via Accessibility API

enum DockIconLocator {
    /// Returns the screen frames of Dock icons whose bundle ID is in `bundleIDs`.
    /// Coordinates are in AppKit screen space (origin bottom-left).
    static func frames(for bundleIDs: Set<String>) -> [CGRect] {
        guard !bundleIDs.isEmpty else { return [] }
        guard let dock = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock"
        ).first else { return [] }

        let axDock = AXUIElementCreateApplication(dock.processIdentifier)
        var listVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axDock, kAXChildrenAttribute as CFString, &listVal) == .success,
              let topChildren = listVal as? [AXUIElement] else { return [] }

        // Dock has multiple AXList children (apps area, persistent area, trash) — scan all
        var allItems: [AXUIElement] = []
        for child in topChildren {
            var itemsVal: CFTypeRef?
            if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &itemsVal) == .success,
               let items = itemsVal as? [AXUIElement] {
                allItems.append(contentsOf: items)
            }
        }

        var result: [CGRect] = []
        for item in allItems {
            // kAXURLAttribute returns a CFURL which bridges to URL, not String
            var urlVal: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXURLAttribute as CFString, &urlVal)
            if let url = urlVal as? URL,
               let bid = Bundle(url: url)?.bundleIdentifier,
               bundleIDs.contains(bid),
               let frame = axFrame(of: item) {
                result.append(frame)
            }
        }
        return result
    }

    private static func axFrame(of element: AXUIElement) -> CGRect? {
        var posVal: CFTypeRef?, sizeVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posVal) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal) == .success,
              let axPos = posVal, let axSize = sizeVal else { return nil }
        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(axPos as! AXValue, .cgPoint, &pos)
        AXValueGetValue(axSize as! AXValue, .cgSize, &size)
        // AX uses top-left origin (same as CG); convert to AppKit bottom-left
        guard let screen = NSScreen.main else { return nil }
        return CGRect(x: pos.x,
                      y: screen.frame.height - pos.y - size.height,
                      width: size.width,
                      height: size.height)
    }
}

// MARK: - Shield ring overlay

/// A pulsing red ring that appears around a Dock icon when the cursor gets close.
final class ShieldRingWindow: NSWindow {
    init(around rect: CGRect) {
        let padding: CGFloat = 18
        let frame = rect.insetBy(dx: -padding, dy: -padding)
        super.init(contentRect: frame, styleMask: [.borderless],
                   backing: .buffered, defer: false)
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let size = frame.size
        contentView = NSHostingView(rootView: ShieldRingView(size: size))
        orderFront(nil)
    }
}

private struct ShieldRingView: View {
    let size: CGSize
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(pulse ? 0.9 : 0.4), lineWidth: pulse ? 4 : 2)
                .frame(width: min(size.width, size.height), height: min(size.width, size.height))
                .scaleEffect(pulse ? 1.12 : 1.0)
                .shadow(color: .red.opacity(0.7), radius: pulse ? 12 : 4)
            Circle()
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                .frame(width: min(size.width, size.height) * 1.35,
                       height: min(size.width, size.height) * 1.35)
                .scaleEffect(pulse ? 1.1 : 0.95)
                .opacity(pulse ? 0.7 : 0.0)
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Dock shield manager

private struct FrameKey: Hashable {
    let x: Int, y: Int, w: Int, h: Int
    init(_ r: CGRect) { x = Int(r.origin.x); y = Int(r.origin.y); w = Int(r.width); h = Int(r.height) }
    var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
}

/// Tracks cursor proximity to blocked Dock icons and repels the cursor + shows a ring.
@MainActor
final class DockShieldManager {
    private let repelRadius: CGFloat = 90
    private var shieldWindows: [FrameKey: ShieldRingWindow] = [:]
    private var cachedFrames: [CGRect] = []
    private var cacheTimestamp: Date = .distantPast

    func handleMouseMove(cursor: CGPoint, blockedBundleIDs: [String]) {
        let frames = iconFrames(for: blockedBundleIDs)
        updateShields(cursor: cursor, frames: frames)
        repelIfNeeded(cursor: cursor, frames: frames)
    }

    func removeAllShields() {
        shieldWindows.values.forEach { $0.close() }
        shieldWindows.removeAll()
    }

    // MARK: - Private

    private func iconFrames(for bundleIDs: [String]) -> [CGRect] {
        let now = Date()
        if now.timeIntervalSince(cacheTimestamp) > 2 {
            cachedFrames = DockIconLocator.frames(for: Set(bundleIDs))
            cacheTimestamp = now
        }
        return cachedFrames
    }

    private func updateShields(cursor: CGPoint, frames: [CGRect]) {
        for frame in frames {
            let key = FrameKey(frame)
            let dist = distance(cursor, to: frame)
            if dist < repelRadius * 1.4 {
                if shieldWindows[key] == nil {
                    shieldWindows[key] = ShieldRingWindow(around: frame)
                }
            } else {
                if let win = shieldWindows[key] {
                    win.close()
                    shieldWindows.removeValue(forKey: key)
                }
            }
        }
        let activeKeys = Set(frames.map { FrameKey($0) })
        for key in shieldWindows.keys where !activeKeys.contains(key) {
            shieldWindows[key]?.close()
            shieldWindows.removeValue(forKey: key)
        }
    }

    private func repelIfNeeded(cursor: CGPoint, frames: [CGRect]) {
        // cursor is in AppKit coords (bottom-left origin)
        guard let screen = NSScreen.main else { return }
        for frame in frames {
            let dist = distance(cursor, to: frame)
            guard dist < repelRadius else { continue }
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let dx = cursor.x - center.x
            let dy = cursor.y - center.y
            let len = sqrt(dx * dx + dy * dy)
            let norm: (CGFloat, CGFloat) = len > 1 ? (dx / len, dy / len) : (0.0, 1.0)
            let push: CGFloat = repelRadius + 20
            // New position in AppKit coords
            let newX = (center.x + norm.0 * push).clamped(to: 0...screen.frame.width)
            let newY = (center.y + norm.1 * push).clamped(to: 0...screen.frame.height)
            // CGWarpMouseCursorPosition uses CG coords (top-left origin)
            CGWarpMouseCursorPosition(CGPoint(x: newX, y: screen.frame.height - newY))
            return
        }
    }

    private func distance(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let cx = max(rect.minX, min(point.x, rect.maxX))
        let cy = max(rect.minY, min(point.y, rect.maxY))
        let dx = point.x - cx
        let dy = point.y - cy
        return sqrt(dx * dx + dy * dy)
    }
}
