import Foundation
import CoreGraphics

// MARK: - WireContour

/// A detected wire contour from a single camera frame.
///
/// Coordinates use Vision framework normalized space (bottom-left origin):
/// - Origin: (0, 0) = bottom-left corner
/// - X-axis: left to right (0 to 1)
/// - Y-axis: bottom to top (0 to 1)
///
/// Each detection gets a new UUID per frame. Wire tracking across frames
/// is handled by Agent 2 (TrackedWire).
struct WireContour: Identifiable, Codable, Equatable {
    /// Unique identifier for this detection (new UUID per frame)
    let id: UUID
    /// Contour path in Vision normalized coordinates (0...1, bottom-left origin)
    let path: [CGPoint]
    /// Detection confidence score (0.0-1.0)
    let confidence: Float
    /// Optional dominant color hint (nil in v1 — color sampling disabled)
    let colorHint: RGB?
    /// Frame capture timestamp for tracking correlation
    let timestamp: Date
    /// Geometric metadata for filtering and diagnostics
    let metadata: ContourMetadata
}

// MARK: - RGB

/// RGB color representation using 0-255 integer components.
struct RGB: Codable, Equatable {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

// MARK: - ContourMetadata

/// Geometric metadata describing a detected contour's shape characteristics.
struct ContourMetadata: Codable, Equatable {
    /// Approximate pixel length of the contour (before normalization)
    let pixelLength: Float
    /// Length-to-thickness ratio (higher = more wire-like)
    let aspectRatio: Float
    /// Straightness score from 0 (curved) to 1 (perfectly straight)
    let straightnessScore: Float
    /// Number of points in the simplified path (post-RDP)
    let pointCount: Int
}
