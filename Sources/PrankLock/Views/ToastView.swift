import SwiftUI

struct ToastView: View {
    let message: String
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.85

    var body: some View {
        Text(message)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.88))
                    .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
            )
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    opacity = 1
                    scale = 1
                }
                withAnimation(.easeOut(duration: 0.4).delay(2.2)) {
                    opacity = 0
                    scale = 0.9
                }
            }
    }
}
