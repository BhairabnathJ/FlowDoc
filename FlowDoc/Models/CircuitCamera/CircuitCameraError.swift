import Foundation

// MARK: - CircuitCameraError

/// Errors specific to the Circuit Camera wire detection pipeline.
///
/// Used across all agents:
/// - Agent 1: `visionProcessingFailed`, `invalidPixelBuffer`, `unsupportedPixelFormat`
/// - Agent 2: `trackingFailed`
/// - Agent 3: `mappingFailed`
/// - Agent 5: `snapshotCaptureFailed`
enum CircuitCameraError: Error, LocalizedError {
    /// Vision framework contour detection failed
    case visionProcessingFailed(String)
    /// CVPixelBuffer is invalid or corrupted
    case invalidPixelBuffer
    /// Pixel buffer format not supported (expected BGRA)
    case unsupportedPixelFormat
    /// Wire tracking across frames failed
    case trackingFailed(String)
    /// Coordinate mapping to breadboard/pins failed
    case mappingFailed(String)
    /// Circuit snapshot capture or save failed
    case snapshotCaptureFailed(String)

    var errorDescription: String? {
        switch self {
        case .visionProcessingFailed(let msg):
            return "Vision processing failed: \(msg)"
        case .invalidPixelBuffer:
            return "Invalid or corrupted pixel buffer"
        case .unsupportedPixelFormat:
            return "Unsupported pixel format (expected BGRA)"
        case .trackingFailed(let msg):
            return "Wire tracking failed: \(msg)"
        case .mappingFailed(let msg):
            return "Coordinate mapping failed: \(msg)"
        case .snapshotCaptureFailed(let msg):
            return "Snapshot capture failed: \(msg)"
        }
    }
}
