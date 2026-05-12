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
