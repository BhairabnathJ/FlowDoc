import SwiftUI
import AVFoundation
import Combine

// MARK: - CircuitCameraView

/// Live camera view with real-time wire detection overlay.
/// Shows wire count and FPS stats on top of the camera preview.
struct CircuitCameraView: View {
    @StateObject private var manager = CircuitCameraManager()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if manager.isRunning {
                CameraPreviewView(session: manager.captureSession)
                    .ignoresSafeArea()
            }

            // Overlay UI
            VStack {
                statsBar
                Spacer()
                if !manager.isCameraAuthorized {
                    permissionPrompt
                    Spacer()
                }
            }
        }
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Wires: \(manager.wireCount)")
                    .font(DesignTokens.Typography.bodyMedium)
                Text(manager.isDetecting ? "Detecting..." : "Idle")
                    .font(DesignTokens.Typography.small)
            }
            .foregroundStyle(.white)
            .padding(DesignTokens.Spacing.sm)
            .background(.black.opacity(0.5))
            .cornerRadius(DesignTokens.CornerRadius.md)

            Spacer()

            Text("\(String(format: "%.0f", manager.fps)) FPS")
                .font(DesignTokens.Typography.small)
                .monospacedDigit()
                .foregroundStyle(.green)
                .padding(DesignTokens.Spacing.sm)
                .background(.black.opacity(0.5))
                .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - Permission Prompt

    private var permissionPrompt: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
            Text("Camera Access Required")
                .font(DesignTokens.Typography.title2)
                .foregroundStyle(.white)
            Text("FlowDoc needs camera access to detect circuit wiring.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignTokens.Spacing.xl)
    }
}

// MARK: - CircuitCameraManager

/// Manages the AVCaptureSession, runs wire detection, and tracks wires across frames.
class CircuitCameraManager: NSObject, ObservableObject {
    @Published var wireCount: Int = 0
    @Published var fps: Double = 0.0
    @Published var isDetecting: Bool = false
    @Published var isRunning: Bool = false
    @Published var isCameraAuthorized: Bool = true

    let captureSession = AVCaptureSession()

    private let detector: VisionFrameworkDetector
    private let tracker: WireTracker
    private let throttle: FrameThrottle
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "com.flowdoc.circuitcamera.video")

    private var frameCount: Int = 0
    private var fpsWindowStart: Date = .now

    override init() {
        self.detector = VisionFrameworkDetector(config: .deviceDefault())
        self.tracker = WireTracker()
        self.throttle = FrameThrottle(targetFPS: WireDetectionConfig.deviceDefault().targetFPS)
        super.init()
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
            setupAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isCameraAuthorized = granted
                    if granted { self?.setupAndRun() }
                }
            }
        default:
            isCameraAuthorized = false
        }
    }

    func stop() {
        captureSession.stopRunning()
        isRunning = false
        isDetecting = false
    }

    // MARK: - Setup

    private func setupAndRun() {
        guard !isRunning else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        // Camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        // Video output for frame processing
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        captureSession.commitConfiguration()

        Task.detached { [weak self] in
            self?.captureSession.startRunning()
            await MainActor.run {
                self?.isRunning = true
                self?.isDetecting = true
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CircuitCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let timestamp = Date()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            // Throttle frame rate
            guard await self.throttle.shouldProcess(timestamp: timestamp) else { return }

            do {
                let contours = try await self.detector.detectWires(
                    in: pixelBuffer,
                    orientation: .up,
                    timestamp: timestamp
                )
                let tracked = await self.tracker.updateTracking(with: contours)
                self.wireCount = tracked.count

                // FPS calculation
                self.frameCount += 1
                let elapsed = Date().timeIntervalSince(self.fpsWindowStart)
                if elapsed >= 1.0 {
                    self.fps = Double(self.frameCount) / elapsed
                    self.frameCount = 0
                    self.fpsWindowStart = .now
                }
            } catch {
                print("CircuitCameraManager: detection error – \(error.localizedDescription)")
            }
        }
    }
}
