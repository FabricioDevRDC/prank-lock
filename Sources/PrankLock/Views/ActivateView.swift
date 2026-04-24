import SwiftUI
import AppKit

struct ActivateView: View {
    @ObservedObject var store: PrankStore
    var onActivated: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @State private var recorded = UnlockCombo.empty
    @State private var isRecording = false
    @State private var peakFlags = NSEvent.ModifierFlags()
    @State private var errorMsg = ""
    @State private var showSuccess = false
    @State private var monitors: [Any] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("🔒 Activate PrankLock")
                .font(.title2.bold())

            intensityPicker
            comboRecorder
            stealthHint

            if !errorMsg.isEmpty {
                Text(errorMsg).foregroundStyle(.red).font(.callout)
            }

            actionButtons
        }
        .padding(28)
        .frame(width: 440)
        .onDisappear { stopRecording() }
        .alert("PrankLock is Active 🔒", isPresented: $showSuccess) {
            Button("Got it") {
                onActivated?()
                closeWindow()
            }
        } message: {
            Text("Locked with: \(recorded.displayString)\n\nHold your combo for 2 seconds to unlock when you return.")
        }
    }

    // MARK: - Subviews

    private var intensityPicker: some View {
        VStack(spacing: 4) {
            Picker("Intensity", selection: $store.intensity) {
                ForEach(PrankIntensity.allCases) { mode in
                    Text("\(mode.emoji)  \(mode.rawValue)").tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(store.intensity.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var comboRecorder: some View {
        GroupBox("Secret unlock combo") {
            VStack(spacing: 10) {
                Text("Press modifier keys (⌃ ⌥ ⌘ ⇧), then release them all. That becomes your combo. Hold it 2 sec while locked to unlock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                comboBox
                    .frame(height: 56)
                    .contentShape(Rectangle())
                    .onTapGesture { if !isRecording { startRecording() } }

                if !recorded.isEmpty && !isRecording {
                    Button("Record again") { startRecording() }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(6)
        }
    }

    private var comboBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isRecording ? Color.accentColor : Color.secondary.opacity(0.4),
                    lineWidth: isRecording ? 2 : 1
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRecording ? Color.accentColor.opacity(0.07) : Color.clear)
                )

            comboBoxLabel
        }
    }

    @ViewBuilder
    private var comboBoxLabel: some View {
        if isRecording {
            if peakFlags.isEmpty {
                Text("Press your keys now…").foregroundStyle(.secondary)
            } else {
                Text(UnlockCombo(flags: peakFlags).displayString)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundColor(.accentColor)
            }
        } else if !recorded.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(recorded.displayString)
                    .font(.system(.title3, design: .rounded).bold())
            }
        } else {
            Text("Tap here to record").foregroundStyle(.secondary)
        }
    }

    private var stealthHint: some View {
        GroupBox {
            HStack(spacing: 6) {
                Image(systemName: "eye.slash.fill").foregroundStyle(.secondary)
                Text("The menu bar icon disappears when locked. Hold your combo 2 sec to unlock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                stopRecording()
                closeWindow()
            }
            .keyboardShortcut(.escape)

            Button("Activate") { activate() }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(recorded.isEmpty || isRecording)
        }
    }

    // MARK: - Recording logic

    private func startRecording() {
        stopRecording()
        recorded = .empty
        peakFlags = NSEvent.ModifierFlags()
        isRecording = true
        errorMsg = ""

        let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [self] event in
            handleFlagsChanged(event.modifierFlags)
            return event
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [self] event in
            DispatchQueue.main.async { self.handleFlagsChanged(event.modifierFlags) }
        }
        if let l = local { monitors.append(l) }
        if let g = global { monitors.append(g) }
    }

    private func handleFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard isRecording else { return }
        let current = flags.intersection([.shift, .control, .option, .command])
        peakFlags.formUnion(current)
        // Confirm when all keys released
        if current.isEmpty && !peakFlags.isEmpty {
            recorded = UnlockCombo(flags: peakFlags)
            isRecording = false
            stopRecording()
        }
    }

    private func stopRecording() {
        isRecording = false
        peakFlags = NSEvent.ModifierFlags()
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }

    // MARK: - Activate

    private func activate() {
        guard !recorded.isEmpty else { errorMsg = "Tap the box and press your keys first."; return }
        guard recorded.relevant.rawValue.nonzeroBitCount >= 2 else {
            errorMsg = "Use at least 2 modifier keys (e.g. ⌃ + ⌥)."
            return
        }
        stopRecording()
        store.lock(with: recorded)
        showSuccess = true
    }

    private func closeWindow() {
        DispatchQueue.main.async {
            NSApp.windows.first(where: { $0.title == "Activate PrankLock" })?.close()
        }
    }
}
