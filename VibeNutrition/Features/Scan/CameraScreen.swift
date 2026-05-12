import SwiftUI
import PhotosUI

struct CameraScreen: View {
    @State private var camera = CameraController()
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    let onCaptured: (Data) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            if camera.permissionDenied {
                permissionDeniedView
            } else if camera.isReady {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) { topBar }
                    .overlay(alignment: .bottom) { bottomControls }
            } else {
                ProgressView().tint(Theme.Palette.accent)
            }
        }
        .task { await camera.configure() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.capturedImageData) { _, data in
            if let data { onCaptured(data) }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    Haptics.tapMedium()
                    onCaptured(data)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tapLight()
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("Close camera")
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
    }

    private var bottomControls: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.xl) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("Pick from photo library")

            Button {
                Haptics.tapHeavy()
                camera.capture()
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 84, height: 84)
                    Circle()
                        .fill(.white)
                        .frame(width: 68, height: 68)
                }
            }
            .accessibilityLabel("Take photo")

            Color.clear.frame(width: 56, height: 56)
        }
        .padding(.bottom, Theme.Spacing.xl)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Palette.textMuted)
            Text("Camera access denied")
                .font(Theme.Type.h2)
                .foregroundStyle(Theme.Palette.text)
            Text("You can still pick a photo from your library, or enable camera in Settings.")
                .font(Theme.Type.body)
                .foregroundStyle(Theme.Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Pick from library")
                    .font(Theme.Type.bodyBold)
                    .foregroundStyle(Theme.Palette.bg)
                    .padding(.vertical, 14)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .background(Theme.Gradients.accent, in: Capsule())
            }
            SecondaryButton(title: "Cancel") { onCancel() }
                .padding(.horizontal, Theme.Spacing.lg)
        }
    }
}
