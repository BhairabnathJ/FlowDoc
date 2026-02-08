import Foundation
import CoreGraphics
import AVFoundation

// MARK: - WireDetectionEngine

/// Protocol for pluggable wire detection implementations.
///
/// The v1 implementation uses Apple's Vision framework (`VisionFrameworkDetector`).
/// Future versions may swap in a CoreML-based detector without changing consumers.
///
/// All returned coordinates use Vision normalized space (bottom-left origin, 0-1 range).
protocol WireDetectionEngine {
    /// Detects wire contours in a camera frame.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Raw camera frame as CVPixelBuffer
    ///   - orientation: Image orientation for Vision coordinate mapping
    ///   - timestamp: Frame capture time for tracking correlation
    /// - Returns: All detected wire contours (unfiltered by confidence)
    /// - Throws: `CircuitCameraError` on processing failure
    func detectWires(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        timestamp: Date
    ) async throws -> [WireContour]
}
