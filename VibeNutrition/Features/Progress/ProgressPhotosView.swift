import SwiftUI
import PhotosUI

/// Before/after progress-photo gallery. Add via camera or library; tap a photo
/// to view it full-screen and delete. Presented as a sheet from the Progress
/// tab's Body section.
struct ProgressPhotosView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var photos: [ProgressPhoto] = []
    @State private var loading = true
    @State private var uploading = false
    @State private var showingCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var viewing: ProgressPhoto?
    @State private var error: String?

    private let columns = [GridItem(.flexible(), spacing: 8),
                           GridItem(.flexible(), spacing: 8),
                           GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    header
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Palette.bg)
                }
                .safeAreaInset(edge: .bottom) { addBar }
        }
        .task { await load() }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraScreen(
                onCaptured: { data in
                    showingCamera = false
                    Task { await upload(data) }
                },
                onCancel: { showingCamera = false }
            )
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await upload(data)
                }
                pickerItem = nil
            }
        }
        .sheet(item: $viewing) { photo in
            ProgressPhotoDetail(photo: photo) {
                Task { await delete(photo) }
            }
        }
        .alert("Error", isPresented: .constant(error != nil), actions: {
            Button("OK") { error = nil }
        }, message: { Text(error ?? "") })
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView().tint(Theme.Palette.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if photos.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(photos) { photo in
                        Button {
                            Haptics.tapLight()
                            viewing = photo
                        } label: {
                            ProgressPhotoThumb(photo: photo)
                                .aspectRatio(1, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.md))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                Spacer(minLength: 100)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Body")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text("Progress photos")
                    .font(Theme.Typo.h2)
                    .foregroundStyle(Theme.Palette.text)
            }
            Spacer()
            Button {
                Haptics.tapLight()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 30, height: 30)
                    .background(Theme.Palette.surface, in: Circle())
            }
        }
    }

    private var addBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                Haptics.tapMedium()
                showingCamera = true
            } label: {
                addLabel(icon: "camera.fill", title: uploading ? "Uploading…" : "Take photo")
            }
            .buttonStyle(.plain)
            .disabled(uploading)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                addLabel(icon: "photo.on.rectangle", title: "Library")
            }
            .disabled(uploading)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)
    }

    private func addLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            Text(title).font(Theme.Typo.bodyBold)
        }
        .foregroundStyle(Theme.Palette.bg)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(Theme.Gradients.accent, in: RoundedRectangle(cornerRadius: Theme.Radii.md))
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
            Text("See your transformation")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
            Text("Add a photo every week. Side-by-side, the change is obvious.")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            photos = try await ProgressPhotoService.shared.list()
        } catch {
            self.error = error.friendlyMessage
        }
    }

    private func upload(_ data: Data) async {
        uploading = true
        defer { uploading = false }
        do {
            // Downscale before upload to keep storage + signed-URL loads light.
            let jpeg = ImageDownscaler.jpeg(from: data, maxDimension: 1280, quality: 0.8) ?? data
            let photo = try await ProgressPhotoService.shared.upload(
                imageData: jpeg, weightKg: nil, notes: nil
            )
            Haptics.tapMedium()
            photos.insert(photo, at: 0)
        } catch {
            self.error = error.friendlyMessage
        }
    }

    private func delete(_ photo: ProgressPhoto) async {
        do {
            try await ProgressPhotoService.shared.delete(photo)
            photos.removeAll { $0.id == photo.id }
            viewing = nil
        } catch {
            self.error = error.friendlyMessage
        }
    }
}

/// Square thumbnail that resolves a short-lived signed URL then loads the image.
private struct ProgressPhotoThumb: View {
    let photo: ProgressPhoto
    @State private var url: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.Palette.surfaceHi
                if let url {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView().tint(Theme.Palette.accent)
                    }
                } else {
                    ProgressView().tint(Theme.Palette.accent)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.width)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .task { url = try? await ProgressPhotoService.shared.signedURL(for: photo.imagePath) }
    }
}

/// Full-screen viewer with a delete action.
private struct ProgressPhotoDetail: View {
    let photo: ProgressPhoto
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView().tint(.white)
                }
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        Haptics.tapLight()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                }
                Spacer()
                VStack(spacing: 4) {
                    Text(dateString)
                        .font(Theme.Typo.bodyBold)
                        .foregroundStyle(.white)
                    if let kg = photo.weightKg {
                        Text("\(kg.grouped(1)) kg")
                            .font(Theme.Typo.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Button(role: .destructive) {
                    Haptics.warn()
                    confirmingDelete = true
                } label: {
                    Label("Delete photo", systemImage: "trash")
                        .font(Theme.Typo.bodyBold)
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Palette.danger.opacity(0.85), in: RoundedRectangle(cornerRadius: Theme.Radii.md))
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.lg)
        }
        .task { url = try? await ProgressPhotoService.shared.signedURL(for: photo.imagePath) }
        .confirmationDialog("Delete this photo?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the photo. You can't undo this.")
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f.string(from: photo.takenAt)
    }
}

/// Decodes, downscales and re-encodes an image as JPEG. Keeps progress-photo
/// uploads small so signed-URL loads stay fast on cellular.
enum ImageDownscaler {
    static func jpeg(from data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
