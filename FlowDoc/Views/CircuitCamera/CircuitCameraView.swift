import SwiftUI
import AVFoundation
import Combine

/// Main view for the Circuit Camera tab. Shows a live camera preview
/// with Vision framework contour detection and text recognition overlays.
struct CircuitCameraView: View {
    @StateObject private var cameraSession = CircuitCameraSession()
    @StateObject private var visionService = CircuitVisionService()
    @Environment(\.colorScheme) var colorScheme
    @State private var viewSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraSession.isReady {
                GeometryReader { geo in
                    ZStack {
                        CameraPreviewView(session: cameraSession.captureSession)
                            .ignoresSafeArea()

                        CircuitCameraOverlay(
                            contourPaths: visionService.contourPaths,
                            recognizedTexts: visionService.recognizedTexts,
                            viewSize: geo.size
                        )
                    }
                    .onAppear { viewSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in viewSize = newSize }
                }
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                        .tint(.white)
                    Text("Starting camera...")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Top info bar
            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .onAppear {
            cameraSession.onFrame = { [weak visionService] buffer in
                visionService?.processFrame(buffer)
            }
            cameraSession.start()
        }
        .onDisappear {
            cameraSession.stop()
            visionService.reset()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("Circuit Camera")
                .font(DesignTokens.Typography.title2)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 3)
            Spacer()
            detectionBadge
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top, DesignTokens.Spacing.sm)
    }

    private var detectionBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(visionService.contourPaths.isEmpty ? Color.gray : Color.green)
                .frame(width: 8, height: 8)
            Text(visionService.contourPaths.isEmpty ? "No objects" : "\(min(visionService.contourPaths.count, 99)) contours")
                .font(DesignTokens.Typography.small)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if !visionService.recognizedTexts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(visionService.recognizedTexts.prefix(5)) { label in
                            Text(label.text)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DesignTokens.Colors.accentPrimary(for: colorScheme).opacity(0.8))
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            }

            Text("Point at a circuit board to detect components")
                .font(DesignTokens.Typography.small)
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, DesignTokens.Spacing.lg)
        }
    }
}

// MARK: - CircuitCameraSession

/// Manages an AVCaptureSession with video data output for real-time frame processing.
class CircuitCameraSession: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    @Published private(set) var isReady = false

    /// Called on each video frame (on a background queue).
    var onFrame: ((CMSampleBuffer) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.flowdoc.circuitcamera", qos: .userInitiated)

    func start() {
        Task { await configure() }
    }

    func stop() {
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
                captureSession.stopRunning()
            }
        }
    }

    private func configure() async {
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
        }
        guard granted else {
            print("CircuitCameraSession: camera permission denied")
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        // Don't let AVCaptureSession reconfigure the audio session - AudioRecorder owns it
        captureSession.automaticallyConfiguresApplicationAudioSession = false

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            print("CircuitCameraSession: cannot add camera input")
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        captureSession.commitConfiguration()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInteractive).async { [captureSession] in
                captureSession.startRunning()
                cont.resume()
            }
        }

        Task { @MainActor in
            self.isReady = true
            print("CircuitCameraSession: ready")
        }
    }
}

extension CircuitCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }
}
