import SwiftUI

/// Fake "OS Update" screen shown in Evil intensity mode.
struct FakeLoadingView: View {
    @State private var progress: Double = 0
    @State private var statusText = "Checking system integrity…"

    private let stages = [
        "Uploading browsing history to HR…",
        "Compressing donut order history…",
        "Optimizing screen-time reports for manager…",
        "Encrypting evidence…",
        "Contacting IT Security…",
        "Almost done — please do not touch the keyboard.",
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "applelogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .foregroundStyle(.white)

                Text("macOS Prank Update")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 320)
                    .tint(.white)

                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(width: 380)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        var stageIndex = 0
        let step = 1.0 / Double(stages.count)

        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { timer in
            withAnimation(.linear(duration: 0.5)) {
                progress = min(progress + step, 1.0)
            }
            if stageIndex < stages.count {
                statusText = stages[stageIndex]
                stageIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}
