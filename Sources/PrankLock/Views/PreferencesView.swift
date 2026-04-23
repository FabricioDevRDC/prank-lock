import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: PrankStore
    @State private var newMessage = ""
    @State private var newBundleID = ""

    var body: some View {
        TabView {
            messagesTab
                .tabItem { Label("Messages", systemImage: "text.bubble") }

            appsTab
                .tabItem { Label("Blocked Apps", systemImage: "app.badge.minus") }

            securityTab
                .tabItem { Label("Security", systemImage: "shield") }

            logTab
                .tabItem { Label("Attempt Log", systemImage: "clock.arrow.circlepath") }
        }
        .padding()
        .frame(width: 480, height: 480)
    }

    // MARK: - Messages tab

    private var messagesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Prank Messages")
                .font(.headline)
            Text("These show as toasts and in the overlay banner when someone touches your Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List(store.customMessages, id: \.self) { msg in
                HStack {
                    Text(msg)
                    Spacer()
                    Button { store.customMessages.removeAll { $0 == msg } } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 160)

            HStack {
                TextField("Add message…", text: $newMessage)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    guard !newMessage.isEmpty else { return }
                    store.customMessages.append(newMessage)
                    newMessage = ""
                }
                .disabled(newMessage.isEmpty)
            }

            Toggle("Silent mode (no sounds)", isOn: $store.silentMode)
        }
        .padding()
    }

    // MARK: - Apps tab

    private var appsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Blocked App Bundle IDs")
                .font(.headline)
            Text("Launching these apps while PrankLock is active will instantly force-quit them.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List(store.blockedAppBundleIDs, id: \.self) { bid in
                HStack {
                    Text(bid).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button { store.blockedAppBundleIDs.removeAll { $0 == bid } } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 160)

            HStack {
                TextField("com.example.App", text: $newBundleID)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    guard !newBundleID.isEmpty else { return }
                    store.blockedAppBundleIDs.append(newBundleID)
                    newBundleID = ""
                }
                .disabled(newBundleID.isEmpty)
            }

            Text("Tip: find bundle IDs with `osascript -e 'id of app \"AppName\"'` in Terminal.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    // MARK: - Security tab

    private var securityTab: some View {
        Form {
            Section("Auto-lock") {
                Stepper(
                    "Auto-lock after \(store.lockAfterSeconds == 0 ? "never" : "\(store.lockAfterSeconds)s")",
                    value: $store.lockAfterSeconds,
                    in: 0...600,
                    step: 30
                )
            }

            Section("Escalation") {
                Stepper(
                    store.realLockAfterFailures == 0
                        ? "Real lock: disabled"
                        : "Real lock after \(store.realLockAfterFailures) failed attempt(s)",
                    value: $store.realLockAfterFailures,
                    in: 0...10
                )
                Text("Triggers ⌘⌃Q macOS lock screen after N wrong passwords.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Webcam") {
                Toggle("Snapshot on wrong password (requires Camera permission)", isOn: $store.snapshotOnFail)
            }
        }
        .padding()
    }

    // MARK: - Log tab

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
                    HStack {
                        Text(entry.date.formatted(date: .omitted, time: .standard))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(entry.action)
                    }
                }
            }
        }
        .padding()
    }
}
