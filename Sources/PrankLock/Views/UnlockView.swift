import SwiftUI

struct UnlockView: View {
    @ObservedObject var store: PrankStore
    @State private var attempt = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var message = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("🔐 PrankLock")
                .font(.largeTitle.bold())

            Text("This Mac is prank-locked.\nEnter the password to unlock.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            SecureField("Password", text: $attempt)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .offset(x: shakeOffset)
                .onSubmit { tryUnlock() }

            if !message.isEmpty {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Button("Unlock") { tryUnlock() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)

            Divider()

            Text("Attempts: \(store.failureCount)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 340)
    }

    private func tryUnlock() {
        if store.unlock(with: attempt) {
            message = "Unlocked!"
        } else {
            attempt = ""
            message = funnyFailMessage()
            Sounds.play(.denied)
            withAnimation(.linear(duration: 0.05).repeatCount(6, autoreverses: true)) {
                shakeOffset = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeOffset = 0 }
        }
    }

    private func funnyFailMessage() -> String {
        let msgs = [
            "Nope 👀",
            "That's not it, buddy.",
            "Nice try. Very bold.",
            "🍩 Still denied.",
            "Wrong password — boss alert sent.",
            "Try again… or don't.",
            "0 out of 100. Not even close.",
        ]
        return msgs.randomElement() ?? "Wrong password."
    }
}
