import Foundation
import AVFoundation
import Combine
import UIKit

/// Manages an AVCaptureSession for in-session photo capture.
/// Created on demand when the user opens the camera sheet from RecordingView.
class CameraController: ObservableObject {
    let session = AVCaptureSession()
    @Published private(set) var isReady          = false
    /// Updated each time a photo is successfully saved – drives the "Saved" toast.
    @Published private(set) var lastCaptureOffset: TimeInterval?

    private let photoOutput = AVCapturePhotoOutput()
    private let delegate    = PhotoDelegate()

    /// Session the captured photos will be linked to.
    let sessionID: UUID

    init(sessionID: UUID) {
        self.sessionID = sessionID
        delegate.onPhotoData = { [weak self] data, offset in
            guard let self = self else { return }
            Task { @MainActor in
                self.savePhoto(data: data, offset: offset)
            }
        }
    }

    // MARK: – Lifecycle

    func start() { Task { await configure() } }
    func stop()  { if session.isRunning { session.stopRunning() } }

    // MARK: – Capture

    /// Snap a photo.  `transcriptOffset` is the live elapsed time at the moment
    /// the shutter button is tapped.
    func capturePhoto(transcriptOffset: TimeInterval) {
        // Ensure there's an active video connection before capturing
        guard let connection = photoOutput.connection(with: .video),
              connection.isEnabled,
              connection.isActive else {
            print("CameraController: no active video connection, skipping capture")
            return
        }

        delegate.pendingOffset = transcriptOffset
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
    }

    // MARK: – Private – session setup

    private func configure() async {
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
        }
        guard granted else {
            print("CameraController: camera permission denied")
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Try to add camera input - log detailed errors for debugging
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("CameraController: ERROR - No back camera found (simulator issue? Try physical device)")
            session.commitConfiguration()
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            print("CameraController: ERROR - Failed to create device input from \(device.localizedName)")
            session.commitConfiguration()
            return
        }

        guard session.canAddInput(input) else {
            print("CameraController: ERROR - Cannot add input to session")
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        print("CameraController: Added input from \(device.localizedName)")

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            print("CameraController: Added photo output")
        } else {
            print("CameraController: ERROR - Cannot add photo output")
        }

        session.commitConfiguration()

        // startRunning() blocks – dispatch to a background thread.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [session = self.session] in
                session.startRunning()
                cont.resume()
            }
        }

        // Wait for AVCaptureSession internal connections to become active
        // (session.startRunning() returns before connections are fully ready)
        try? await Task.sleep(for: .milliseconds(500))

        // Verify the video connection is actually active
        if let connection = photoOutput.connection(with: .video) {
            print("CameraController: Video connection - enabled: \(connection.isEnabled), active: \(connection.isActive)")
        } else {
            print("CameraController: ERROR - No video connection found after session start")
        }

        // Defer @Published update to avoid "Publishing changes from within view updates"
        await MainActor.run {
            self.isReady = true
            print("CameraController: session ready (isRunning: \(session.isRunning))")
        }
    }

    // MARK: – Private – photo processing

    /// Write JPEG to disk, persist the MediaCapture record, and publish the offset.
    /// Must run on @MainActor (DatabaseManager is actor-isolated).
    private func savePhoto(data: Data?, offset: TimeInterval) {
        guard let data  = data,
              let image = UIImage(data: data),
              let jpeg  = image.jpegData(compressionQuality: 0.85) else {
            print("CameraController: image processing failed")
            return
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaDir = docs.appendingPathComponent("Media").appendingPathComponent(sessionID.uuidString)
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let fileName = "\(UUID()).jpg"
        let fileURL  = mediaDir.appendingPathComponent(fileName)

        do { try jpeg.write(to: fileURL) }
        catch {
            print("CameraController: write failed – \(error)")
            return
        }

        let capture = MediaCapture(
            sessionID:        sessionID,
            type:             .photo,
            transcriptOffset: offset,
            fileURL:          fileURL
        )
        DatabaseManager.shared.saveMediaCapture(capture, for: sessionID)

        // Defer @Published update to avoid "Publishing changes from within view updates"
        Task { @MainActor in
            self.lastCaptureOffset = offset
            print("CameraController: saved \(fileName) at \(Session.formatDuration(offset))")
        }
    }
}

// MARK: – PhotoDelegate

/// Isolated NSObject delegate for AVCapturePhotoOutput.  Extracts raw Data on the
/// callback thread so only Sendable types cross the actor boundary.
private class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    /// Closure receives (imageData, transcriptOffset).  Both are Sendable.
    var onPhotoData:   ((Data?, TimeInterval) -> Void)?
    /// Set by CameraController.capturePhoto() immediately before firing the output.
    var pendingOffset: TimeInterval = 0

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("PhotoDelegate: \(error)")
            return
        }
        onPhotoData?(photo.fileDataRepresentation(), pendingOffset)
    }
}
