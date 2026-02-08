import Foundation

// MARK: - WireTrackingConfig

/// Configuration parameters for IOU-based wire tracking across frames.
///
/// Controls how aggressively wires are matched (IOU threshold),
/// how long missing wires are retained, and velocity smoothing behavior.
struct WireTrackingConfig: Codable, Equatable {
    /// Minimum IOU overlap to consider two bounding boxes the same wire (0.0-1.0)
    var iouThreshold: Float
    /// Frames a wire can be missing before its track is removed (15 = 1 sec at 15 FPS)
    var maxMissingFrames: Int
    /// EMA alpha for velocity smoothing (higher = more weight on latest measurement)
    var velocitySmoothingFactor: Float
    /// Minimum tracking confidence to keep a track active (0.0-1.0)
    var minTrackingConfidence: Float

    /// Returns recommended defaults for wire tracking.
    static func defaults() -> WireTrackingConfig {
        WireTrackingConfig(
            iouThreshold: 0.3,
            maxMissingFrames: 15,
            velocitySmoothingFactor: 0.7,
            minTrackingConfidence: 0.5
        )
    }
}
