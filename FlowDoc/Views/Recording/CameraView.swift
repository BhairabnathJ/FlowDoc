import SwiftUI
import AVFoundation
import UIKit

/// Full-screen camera overlay shown during an active recording session.
/// Captures photos and links them to the session's transcript timeline.
struct CameraView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @Environment(\.dismiss)     var dismiss
    @Environment(\.colorScheme) var colorScheme

    // Separate the camera controller lifecycle from the view init
    // to prevent multiple initializations during SwiftUI view updates
    let sessionID: UUID
    @StateObject private var camera: CameraController

    @State private var flashFeedback = false
    @State private var toastMessage:  String?

    init(sessionID: UUID) {
        self.sessionID = sessionID
        // Initialize @StateObject with the sessionID
        _camera = StateObject(wrappedValue: CameraController(sessionID: sessionID))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isReady {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            }

            // White flash on shutter tap
            if flashFeedback {
                Color.white.opacity(0.75).ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                if let msg = toastMessage { toast(msg) }
                bottomBar
            }
        }
        .onAppear   { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.lastCaptureOffset) { _, offset in
            guard let offset = offset else { return }
            toastMessage = "Saved at \(Session.formatDuration(offset))"
            Task {
                try? await Task.sleep(for: .seconds(2))
                toastMessage = nil
            }
        }
    }

    // MARK: – Top bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3)
            }
            .padding(DesignTokens.Spacing.lg)
            Spacer()
        }
    }

    // MARK: – Bottom bar

    private var bottomBar: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 68, height: 68)
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 78, height: 78)
                }
            }
            Text("Photo")
                .font(DesignTokens.Typography.small)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
        }
        .padding(.bottom, DesignTokens.Spacing.xxl)
    }

    // MARK: – Toast

    private func toast(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Typography.bodyMedium)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical,   DesignTokens.Spacing.sm)
            .background(.black.opacity(0.6))
            .cornerRadius(DesignTokens.CornerRadius.md)
            .padding(.bottom, DesignTokens.Spacing.xl)
    }

    // MARK: – Capture action

    private func capturePhoto() {
        camera.capturePhoto(transcriptOffset: audioRecorder.elapsedTime)
        withAnimation(.easeOut(duration: 0.1)) { flashFeedback = true }
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.2)) { flashFeedback = false }
        }
    }
}

// MARK: – CameraPreviewView

/// UIViewRepresentable that wraps AVCaptureVideoPreviewLayer.
/// Uses the layerClass pattern so the preview layer auto-sizes with the view bounds.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session      = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    /// UIView whose backing layer IS the AVCaptureVideoPreviewLayer.
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
