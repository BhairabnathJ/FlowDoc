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
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                if manager.isRunning {
                    CameraPreviewView(session: manager.captureSession)
                        .ignoresSafeArea()

                    // Wire detection overlay
                    WireOverlayView(
                        trackedWires: manager.trackedWires,
                        mappedConnections: manager.mappedConnections,
                        viewSize: proxy.size
                    )
                    .ignoresSafeArea()
                }

                // Calibration corner dots
                ForEach(Array(manager.calibrationCorners.enumerated()), id: \.offset) { index, corner in
                    Circle()
                        .fill(calibrationDotColor(index: index))
                        .frame(width: 16, height: 16)
                        .position(visionToUIKit(corner, in: proxy.size))
                }

                // Calibration tap overlay
                if manager.isCalibrating {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let visionPt = uiKitToVision(location, in: proxy.size)
                            manager.addCalibrationCorner(visionPt)
                        }

                    calibrationInstructions
                }

                // Overlay UI
                VStack {
                    statsBar
                    Spacer()
                    if !manager.isCameraAuthorized {
                        permissionPrompt
                        Spacer()
                    }
                    calibrationBar
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
                Text("Tracked: \(manager.wireCount)")
                    .font(DesignTokens.Typography.bodyMedium)
                Text("IDs: \(manager.trackedWireIDs.count) stable")
                    .font(DesignTokens.Typography.small)
                if manager.isCalibrated {
                    Text("Mapped: \(manager.mappedConnections.count)")
                        .font(DesignTokens.Typography.small)
                }
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

    // MARK: - Calibration Bar

    private var calibrationBar: some View {
        HStack {
            if manager.isCalibrating {
                Button("Cancel") {
                    manager.isCalibrating = false
                    manager.calibrationCorners = []
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(.red.opacity(0.7))
                .cornerRadius(DesignTokens.CornerRadius.md)
            } else if manager.isCalibrated {
                Button("Re-calibrate") {
                    manager.resetCalibration()
                    manager.startCalibration()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(.orange.opacity(0.7))
                .cornerRadius(DesignTokens.CornerRadius.md)
            } else {
                Button("Calibrate Board") {
                    manager.startCalibration()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(.blue.opacity(0.7))
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
        }
        .padding(.bottom, DesignTokens.Spacing.xl)
    }

    // MARK: - Calibration Instructions

    private var calibrationInstructions: some View {
        VStack {
            Spacer()
            let remaining = 4 - manager.calibrationCorners.count
            Text("Tap \(remaining) corner\(remaining == 1 ? "" : "s") of your breadboard")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundStyle(.white)
                .padding(DesignTokens.Spacing.md)
                .background(.black.opacity(0.7))
                .cornerRadius(DesignTokens.CornerRadius.md)

            Text("Order: bottom-left → bottom-right → top-right → top-left")
                .font(DesignTokens.Typography.small)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 80)
        }
    }

    // MARK: - Helpers

    private func calibrationDotColor(index: Int) -> Color {
        [Color.red, .green, .blue, .yellow][index % 4]
    }

    /// Converts Vision normalized coords (bottom-left origin) to UIKit view coords.
    private func visionToUIKit(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: (1.0 - point.y) * size.height)
    }

    /// Converts UIKit view coords to Vision normalized coords (bottom-left origin).
    private func uiKitToVision(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x / size.width, y: 1.0 - point.y / size.height)
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
    @Published var trackedWireIDs: [UUID] = []
    @Published var trackedWires: [TrackedWire] = []
    @Published var mappedConnections: [MappedConnection] = []
    @Published var isCalibrated: Bool = false
    @Published var fps: Double = 0.0
    @Published var isDetecting: Bool = false
    @Published var isRunning: Bool = false
    @Published var isCameraAuthorized: Bool = true
    @Published var isCalibrating: Bool = false
    @Published var calibrationCorners: [CGPoint] = []

    let captureSession = AVCaptureSession()

    private let detector: VisionFrameworkDetector
    private let tracker: WireTracker
    private let mapper = CoordinateMapper()
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

    // MARK: - Calibration

    /// Enters calibration mode where the user taps 4 breadboard corners.
    func startCalibration() {
        calibrationCorners = []
        isCalibrating = true
    }

    /// Records a corner tap during calibration.
    /// After 4 taps, automatically computes the homography and exits calibration mode.
    ///
    /// - Parameter point: Tap location in Vision normalized coordinates (bottom-left origin)
    func addCalibrationCorner(_ point: CGPoint) {
        guard isCalibrating, calibrationCorners.count < 4 else { return }
        calibrationCorners.append(point)

        if calibrationCorners.count == 4 {
            mapper.calibrate(corners: calibrationCorners)
            isCalibrated = mapper.isCalibrated
            isCalibrating = false
        }
    }

    /// Clears calibration and mapped connections.
    func resetCalibration() {
        mapper.resetCalibration()
        isCalibrated = false
        mappedConnections = []
        calibrationCorners = []
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
                self.trackedWires = tracked
                self.wireCount = tracked.count
                self.trackedWireIDs = tracked.map(\.id)

                // Coordinate mapping (runs only when calibrated)
                if self.mapper.isCalibrated {
                    let mapped = try await self.mapper.mapToGrid(tracked)
                    self.mappedConnections = mapped
                }

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
