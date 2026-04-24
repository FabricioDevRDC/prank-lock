import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct PreferencesView: View {
    @ObservedObject var store: PrankStore
    @State private var newMessage = ""
    @State private var newBundleID = ""
    @State private var isDropTargeted = false

    var body: some View {
        TabView {
            messagesTab .tabItem { Label("Messages",     systemImage: "text.bubble") }
            appsTab     .tabItem { Label("Blocked Apps", systemImage: "app.badge.minus") }
            securityTab .tabItem { Label("Security",     systemImage: "shield") }
            logTab      .tabItem { Label("Attempt Log",  systemImage: "clock.arrow.circlepath") }
        }
        .padding()
        .frame(width: 500, height: 540)
    }

    // MARK: - Messages

    private var messagesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Custom Prank Messages",
                          "These pop up as toasts when someone touches your Mac while locked.")

            List(store.customMessages, id: \.self) { msg in
                HStack {
                    Text(msg)
                    Spacer()
                    Button { store.customMessages.removeAll { $0 == msg } }
                    label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 120)

            HStack {
                TextField("Add message…", text: $newMessage)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addMessage() }
                Button("Add", action: addMessage)
                    .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Divider()

            Toggle("Silent mode — no sound effects", isOn: $store.silentMode)

            if !store.silentMode {
                Divider()
                soundsSection
            }
        }
        .padding()
    }

    private var soundsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Sound Effects",
                          "Scanned from /System/Library/Sounds and ~/Library/Sounds on this Mac.")

            soundRow("On click / blocked app", slot: $store.soundDenied)
            soundRow("On keyboard input",       slot: $store.soundAlert)
            soundRow("On window bounce",        slot: $store.soundBounce)
        }
    }

    private func soundRow(_ label: String, slot: Binding<String>) -> some View {
        HStack {
            Text(label)
                .frame(width: 180, alignment: .leading)
            Picker("", selection: slot) {
                Text("None").tag("")
                ForEach(store.availableSounds) { s in
                    Text(s.displayName).tag(s.id)
                }
            }
            .frame(width: 130)
            Button {
                if !slot.wrappedValue.isEmpty {
                    SoundPlayer.shared.play(named: slot.wrappedValue, from: store.availableSounds)
                }
            } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.borderless)
            .disabled(slot.wrappedValue.isEmpty)
            .help("Preview")
        }
    }

    private func addMessage() {
        let m = newMessage.trimmingCharacters(in: .whitespaces)
        guard !m.isEmpty else { return }
        store.customMessages.append(m)
        newMessage = ""
    }

    // MARK: - Blocked Apps

    private var appsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Blocked Apps",
                          "Drag apps from Finder. They are force-quit the moment they launch or are activated while locked.")

            ZStack {
                dropZoneBackground
                    .frame(minHeight: 180)

                if store.blockedAppBundleIDs.isEmpty {
                    emptyDropHint
                } else {
                    blockedAppList
                }
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)

            Divider()

            HStack {
                TextField("or paste bundle ID — com.apple.Safari", text: $newBundleID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addBundleID() }
                Button("Add", action: addBundleID)
                    .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("Tip: find bundle IDs with  osascript -e 'id of app \"AppName\"'  in Terminal.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var dropZoneBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
                isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, dash: isDropTargeted ? [] : [6])
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.07) : Color.clear)
            )
    }

    private var emptyDropHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.app")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Drop apps here")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
    }

    private var blockedAppList: some View {
        List(store.blockedAppBundleIDs, id: \.self) { bid in
            HStack(spacing: 10) {
                appIcon(for: bid)
                VStack(alignment: .leading, spacing: 1) {
                    Text(appName(for: bid)).font(.body)
                    Text(bid).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Button { store.blockedAppBundleIDs.removeAll { $0 == bid } }
                label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }

    private func addBundleID() {
        let bid = newBundleID.trimmingCharacters(in: .whitespaces)
        guard !bid.isEmpty, !store.blockedAppBundleIDs.contains(bid) else { return }
        store.blockedAppBundleIDs.append(bid)
        newBundleID = ""
    }

    // MARK: - Security

    private var securityTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current unlock combo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let combo = store.unlockCombo
                    Text(combo.isEmpty ? "Not set — activate PrankLock to record one" : combo.displayString)
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundColor(combo.isEmpty ? .secondary : .primary)
                    Text("Hold this combo for 2 seconds while locked to unlock silently.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: { Text("Unlock Combo") }

            Section {
                Stepper(
                    store.lockAfterSeconds == 0
                        ? "Auto-lock: disabled"
                        : "Auto-lock after \(store.lockAfterSeconds) seconds of inactivity",
                    value: $store.lockAfterSeconds,
                    in: 0...600,
                    step: 30
                )
                .help("Automatically activates PrankLock if the Mac is idle for this long.")
            } header: { Text("Auto-lock") }

            Section {
                Toggle("Also lock macOS screen when PrankLock activates", isOn: $store.alsoLockScreen)
                Text("Triggers ⌘⌃Q alongside PrankLock so the login screen also appears.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Screen Lock") }
        }
        .padding()
        .formStyle(.grouped)
    }

    // MARK: - Attempt Log

    private var logTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Attempt Log").font(.headline)
                Spacer()
                Button("Clear") { store.attemptLog = [] }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
            }

            if store.attemptLog.isEmpty {
                Text("No attempts recorded yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.attemptLog) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.date.formatted(date: .omitted, time: .standard))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .leading)
                        Text(entry.action)
                            .font(.callout)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Drag & drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard
                    let data = item as? Data,
                    let url  = URL(dataRepresentation: data, relativeTo: nil),
                    url.pathExtension == "app"
                else { return }

                let bid = Bundle(url: url)?.bundleIdentifier
                    ?? (NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist"))?["CFBundleIdentifier"] as? String)
                guard let bundleID = bid else { return }

                DispatchQueue.main.async {
                    if !self.store.blockedAppBundleIDs.contains(bundleID) {
                        self.store.blockedAppBundleIDs.append(bundleID)
                    }
                }
            }
        }
        return true
    }

    // MARK: - Helpers

    private func appName(for bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleName"] as? String }
            ?? bundleID
    }

    private func appIcon(for bundleID: String) -> some View {
        let icon: NSImage = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)!
        return Image(nsImage: icon).resizable().frame(width: 28, height: 28)
    }

    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }
}
