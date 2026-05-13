import SwiftUI

struct PlanGenerationView: View {
    let onboarding: OnboardingState?
    let onReady: (NutritionEngine.Result, NutritionEngine.Inputs) -> Void

    @State private var generator = PlanGenerator()
    @State private var pulse = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                Circle()
                    .fill(Theme.Gradients.accent)
                    .frame(width: 96, height: 96)
                    .scaleEffect(pulse ? 1.06 : 0.94)
                    .shadow(color: Theme.Palette.accent.opacity(0.5), radius: 28)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundStyle(Theme.Palette.bg)
                    )

                VStack(spacing: Theme.Spacing.md) {
                    Text("Building your nutrition plan")
                        .font(Theme.Typo.h2)
                        .foregroundStyle(Theme.Palette.text)
                        .multilineTextAlignment(.center)

                    Text(generator.stage.rawValue)
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Palette.textMuted)
                        .multilineTextAlignment(.center)
                        .id(generator.stage) // re-animate when text changes
                        .transition(.opacity)
                }
                .padding(.horizontal, Theme.Spacing.lg)

                OnboardingProgressBar(progress: generator.progress)
                    .frame(width: 220)

                if generator.stage == .failed {
                    PrimaryButton(title: "Retry") {
                        Task { await generator.run(using: onboarding) }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    if let msg = generator.errorMessage {
                        Text(msg)
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.lg)
                    }
                }

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
            Task { await generator.run(using: onboarding) }
        }
        .onChange(of: generator.stage) { _, new in
            if new == .ready, let result = generator.result, let inputs = generator.inputs {
                Haptics.success()
                // Brief pause so the user sees the "ready" state before sliding away.
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    onReady(result, inputs)
                }
            }
        }
        .animation(.easeInOut(duration: Theme.Motion.base), value: generator.stage)
    }
}

#Preview {
    // The view kicks off PlanGenerator on appear, which hits Supabase. The
    // preview is therefore most useful for the static loading layout —
    // pulse animation + progress bar.
    PlanGenerationView(onboarding: nil) { _, _ in }
}
