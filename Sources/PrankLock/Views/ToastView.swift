import SwiftUI

struct ToastView: View {
    let message: String
    @State private var opacity: Double = 0

    var body: some View {
        Text(message)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .shadow(radius: 12)
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.25)) { opacity = 1 }
                withAnimation(.easeOut(duration: 0.5).delay(2.0)) { opacity = 0 }
            }
    }
}
