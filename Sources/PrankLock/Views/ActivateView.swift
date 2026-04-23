import SwiftUI

struct ActivateView: View {
    @ObservedObject var store: PrankStore
    @State private var pin = ""
    @State private var confirm = ""
    @State private var errorMsg = ""
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("🔒 Activate PrankLock")
                .font(.title2.bold())

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

            GroupBox("Set PIN / Password") {
                VStack(spacing: 12) {
                    SecureField("Enter PIN or passphrase", text: $pin)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Confirm", text: $confirm)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(4)
            }

            if !errorMsg.isEmpty {
                Text(errorMsg).foregroundStyle(.red).font(.callout)
            }

            HStack(spacing: 16) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button("Activate") { activate() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 420)
        .alert("PrankLock is Active 🔒", isPresented: $showSuccess) {
            Button("Got it") { dismiss() }
        } message: {
            Text("Your Mac is now prank-protected. Come back and enter your password to unlock.")
        }
    }

    private func activate() {
        guard !pin.isEmpty else { errorMsg = "Please enter a password or PIN."; return }
        guard pin == confirm else { errorMsg = "Passwords don't match."; return }
        store.lock(with: pin)
        showSuccess = true
    }
}
