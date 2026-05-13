import AVFoundation
import UIKit
import SwiftUI

@MainActor
@Observable
final class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    nonisolated let session = AVCaptureSession()
    nonisolated private let output = AVCapturePhotoOutput()
    nonisolated private let queue = DispatchQueue(label: "vibe.camera.queue")

    private(set) var isReady = false
    private(set) var permissionDenied = false
    var capturedImageData: Data?

    func configure() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { permissionDenied = true; return }
        case .denied, .restricted:
            permissionDenied = true; return
        @unknown default:
            permissionDenied = true; return
        }

        queue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            self.session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input),
                self.session.canAddOutput(self.output)
            else { return }

            self.session.addInput(input)
            self.session.addOutput(self.output)
            self.output.maxPhotoQualityPrioritization = .balanced
        }
        try? await Task.sleep(for: .milliseconds(50))
        await MainActor.run { isReady = true }
        queue.async { [weak self] in self?.session.startRunning() }
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .balanced
        output.capturePhoto(with: settings, delegate: self)
    }

    func stop() {
        queue.async { [weak self] in self?.session.stopRunning() }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in
            Haptics.tapMedium()
            capturedImageData = data
        }
    }
}

/// Thin UIView wrapper exposing the camera preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
