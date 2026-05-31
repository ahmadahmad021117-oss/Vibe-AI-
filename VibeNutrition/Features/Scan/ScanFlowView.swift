import SwiftUI

/// Coordinator for the camera → analyze → review pipeline.
struct ScanFlowView: View {
    enum Stage: Equatable {
        case capture
        case analyzing(Data)
        case review(Data, String, AnalyzedFood)
        case failed(String)
    }

    @State private var stage: Stage = .capture
    let onClose: (Bool) -> Void  // Bool = whether a log was written

    var body: some View {
        ZStack {
            switch stage {
            case .capture:
                CameraScreen(
                    onCaptured: { data in stage = .analyzing(data) },
                    onCancel: { onClose(false) }
                )

            case .analyzing(let data):
                AnalyzingView(imageData: data) {
                    await analyze(data: data)
                }

            case let .review(data, path, food):
                ScanReviewView(
                    imageData: data,
                    imagePath: path,
                    food: food,
                    onDone: { onClose(true) },
                    onRetake: { stage = .capture }
                )

            case .failed(let message):
                FailureView(message: message, onRetry: { stage = .capture }, onCancel: { onClose(false) })
            }
        }
    }

    private func analyze(data: Data) async {
        do {
            let result = try await FoodScanService.shared.analyze(imageData: data)
            stage = .review(data, result.path, result.food)
        } catch {
            stage = .failed(error.friendlyMessage)
        }
    }
}

private struct AnalyzingView: View {
    let imageData: Data
    let perform: () async -> Void
    @State private var pulse = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            if let ui = UIImage(data: imageData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(.black.opacity(0.55))
            }
            VStack(spacing: Theme.Spacing.md) {
                // Larger pulse range + outer halo. The original 0.92→1.08
                // pulse was almost imperceptible on this dim overlay; users
                // weren't sure if the app had frozen during the ~2s analyze.
                ZStack {
                    Circle()
                        .fill(Theme.Palette.accent.opacity(0.35))
                        .frame(width: 140, height: 140)
                        .blur(radius: 24)
                        .scaleEffect(pulse ? 1.15 : 0.85)
                    Circle()
                        .fill(Theme.Gradients.accent)
                        .frame(width: 96, height: 96)
                        .scaleEffect(pulse ? 1.12 : 0.88)
                        .shadow(color: Theme.Palette.accent.opacity(0.7), radius: 28)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundStyle(Theme.Palette.bg)
                                .rotationEffect(.degrees(pulse ? 4 : -4))
                        )
                }
                Text("Spotting every calorie…")
                    .font(Theme.Typo.h2)
                    .foregroundStyle(.white)
                Text("Our AI is reading the plate.")
                    .font(Theme.Typo.body)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .task {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) { pulse.toggle() }
            await perform()
        }
    }
}

private struct FailureView: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.Palette.warning)
                Text("Couldn't analyze that photo")
                    .font(Theme.Typo.h2)
                    .foregroundStyle(Theme.Palette.text)
                Text(message)
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                VStack(spacing: Theme.Spacing.sm) {
                    PrimaryButton(title: "Try again", action: onRetry)
                    SecondaryButton(title: "Cancel", action: onCancel)
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
}
