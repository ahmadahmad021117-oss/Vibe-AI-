import SwiftUI

struct OnboardingProgressBar: View {
    let progress: Double // 0...1

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Palette.surface)
                Capsule()
                    .fill(Theme.Gradients.accent)
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: Theme.Motion.base), value: progress)
    }
}

#Preview {
    VStack(spacing: 16) {
        OnboardingProgressBar(progress: 0.0)
        OnboardingProgressBar(progress: 0.35)
        OnboardingProgressBar(progress: 0.75)
        OnboardingProgressBar(progress: 1.0)
    }
    .padding()
    .background(Theme.Palette.bg)
    .preferredColorScheme(.dark)
}
