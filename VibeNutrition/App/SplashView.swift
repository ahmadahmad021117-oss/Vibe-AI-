import SwiftUI

struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                Circle()
                    .fill(Theme.Gradients.accent)
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulse ? 1.05 : 0.95)
                    .shadow(color: Theme.Palette.accent.opacity(0.6), radius: 32)
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 56, weight: .heavy))
                            .foregroundStyle(Theme.Palette.bg)
                    )
                Text("VibeCal")
                    .font(Theme.Typo.h1)
                    .foregroundStyle(Theme.Palette.text)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulse.toggle()
                }
            }
        }
    }
}

#Preview {
    SplashView()
        .preferredColorScheme(.dark)
}
