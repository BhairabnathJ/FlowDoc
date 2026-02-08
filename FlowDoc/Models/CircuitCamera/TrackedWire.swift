import Foundation
import CoreGraphics

// MARK: - TrackedWire

/// A wire tracked across multiple frames with a stable identity.
///
/// Agent 1 (`VisionFrameworkDetector`) produces new `WireContour` UUIDs every frame.
/// Agent 2 (`WireTracker`) matches contours across frames using IOU and assigns
/// a stable `id` that persists as long as the wire remains visible.
///
/// Consumers: Agent 3 (Mapping), Agent 4 (Rendering), Agent 5 (Persistence).
struct TrackedWire: Identifiable, Codable, Equatable {
    /// Stable identifier that persists across frames (assigned by WireTracker)
    let id: UUID
    /// Current frame's detection data from Agent 1
    let contour: WireContour
    /// Estimated motion in Vision normalized coordinates per second (EMA-smoothed)
    let velocity: CGVector
    /// Number of consecutive frames this wire has been tracked
    let ageFrames: Int
    /// Tracking quality score (0.0 = poor match, 1.0 = excellent)
    let trackingConfidence: Float

    // MARK: - Computed Helpers

    /// Axis-aligned bounding box of the contour path in normalized coordinates.
    var boundingBox: CGRect {
        guard let first = contour.path.first else { return .zero }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for point in contour.path.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Center point of the contour's bounding box in normalized coordinates.
    var center: CGPoint {
        let bbox = boundingBox
        return CGPoint(x: bbox.midX, y: bbox.midY)
    }
}
