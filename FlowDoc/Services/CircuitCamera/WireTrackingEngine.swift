import Foundation

// MARK: - WireTrackingEngine

/// Protocol for wire tracking implementations.
///
/// Takes per-frame `[WireContour]` from Agent 1 (each with ephemeral UUIDs)
/// and returns `[TrackedWire]` with stable IDs that persist across frames.
///
/// The v1 implementation uses IOU bounding-box matching (`WireTracker`).
protocol WireTrackingEngine {
    /// Updates tracking state with new detections and returns tracked wires.
    ///
    /// - Parameter contours: Wire contours detected in the current frame
    /// - Returns: Tracked wires with stable IDs, velocity, and age
    func updateTracking(with contours: [WireContour]) async -> [TrackedWire]
}
