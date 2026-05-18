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
            stage = .failed(error.localizedDescription)
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
                Circle()
                    .fill(Theme.Gradients.accent)
                    .frame(width: 88, height: 88)
                    .scaleEffect(pulse ? 1.08 : 0.92)
                    .shadow(color: Theme.Palette.accent.opacity(0.6), radius: 24)
                    .overlay(Image(systemName: "sparkles").font(.system(size: 34, weight: .heavy)).foregroundStyle(Theme.Palette.bg))
                Text("Analyzing your meal…")
                    .font(Theme.Typo.h2)
                    .foregroundStyle(.white)
                Text("Identifying items and estimating macros.")
                    .font(Theme.Typo.body)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .preferredColorScheme(.dark)
        .task {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse.toggle() }
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
