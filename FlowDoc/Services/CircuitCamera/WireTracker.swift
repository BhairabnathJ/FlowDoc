import Foundation
import CoreGraphics

// MARK: - WireTracker

/// IOU-based wire tracker that assigns stable IDs across frames.
///
/// Each frame, Agent 1 produces `[WireContour]` with ephemeral UUIDs.
/// `WireTracker` matches new contours to existing tracks using bounding-box
/// IOU (Intersection Over Union), maintaining stable identities.
///
/// Tracks are removed after `maxMissingFrames` consecutive misses (default 15 = 1 sec).
/// Velocity is smoothed with an exponential moving average.
class WireTracker: WireTrackingEngine {
    private let config: WireTrackingConfig
    private var activeTracks: [UUID: TrackState] = [:]
    private var lastTimestamp: Date?

    /// Creates a tracker with the given configuration.
    ///
    /// - Parameter config: Tracking parameters (default: recommended values)
    init(config: WireTrackingConfig = .defaults()) {
        self.config = config
    }

    // MARK: - WireTrackingEngine

    func updateTracking(with contours: [WireContour]) async -> [TrackedWire] {
        let timestamp = contours.first?.timestamp ?? Date()
        let timeDelta = lastTimestamp.map { timestamp.timeIntervalSince($0) } ?? 0
        lastTimestamp = timestamp

        // Build bounding boxes for new contours
        let newEntries: [(contour: WireContour, bbox: CGRect, center: CGPoint)] = contours.map { c in
            let bbox = Self.boundingBox(for: c)
            let center = CGPoint(x: bbox.midX, y: bbox.midY)
            return (c, bbox, center)
        }

        // Greedy IOU matching
        let matches = greedyMatch(newEntries: newEntries)

        var matchedTrackIDs: Set<UUID> = []
        var matchedContourIndices: Set<Int> = []

        // Update matched tracks
        for (trackID, contourIndex) in matches {
            matchedTrackIDs.insert(trackID)
            matchedContourIndices.insert(contourIndex)

            guard var track = activeTracks[trackID] else { continue }
            let entry = newEntries[contourIndex]

            // EMA velocity
            let velocity: CGVector
            if timeDelta > 0 {
                let rawVx = (entry.center.x - track.lastCenter.x) / timeDelta
                let rawVy = (entry.center.y - track.lastCenter.y) / timeDelta
                let alpha = CGFloat(config.velocitySmoothingFactor)
                velocity = CGVector(
                    dx: alpha * rawVx + (1 - alpha) * track.velocity.dx,
                    dy: alpha * rawVy + (1 - alpha) * track.velocity.dy
                )
            } else {
                velocity = track.velocity
            }

            // Tracking confidence: IOU × 0.8 + age bonus (up to 0.2)
            let iouValue = Self.iou(track.lastBBox, entry.bbox)
            let ageBonus = min(Float(track.ageFrames) / 30.0, 0.2)
            let confidence = min(1.0, iouValue * 0.8 + ageBonus)

            track.lastContour = entry.contour
            track.lastBBox = entry.bbox
            track.lastCenter = entry.center
            track.velocity = velocity
            track.ageFrames += 1
            track.missedFrames = 0
            track.trackingConfidence = confidence

            activeTracks[trackID] = track
        }

        // Create new tracks for unmatched contours
        for (index, entry) in newEntries.enumerated() where !matchedContourIndices.contains(index) {
            let newID = UUID()
            activeTracks[newID] = TrackState(
                id: newID,
                lastContour: entry.contour,
                lastBBox: entry.bbox,
                lastCenter: entry.center,
                velocity: .zero,
                ageFrames: 1,
                missedFrames: 0,
                trackingConfidence: entry.contour.confidence * 0.5
            )
        }

        // Age out unmatched existing tracks
        var expiredIDs: [UUID] = []
        for (trackID, var track) in activeTracks where !matchedTrackIDs.contains(trackID) {
            // Skip newly created tracks (they were just added above)
            if track.ageFrames <= 1 && track.missedFrames == 0 { continue }

            track.missedFrames += 1
            if track.missedFrames > config.maxMissingFrames {
                expiredIDs.append(trackID)
            } else {
                activeTracks[trackID] = track
            }
        }
        for id in expiredIDs {
            activeTracks.removeValue(forKey: id)
        }

        // Build output
        return activeTracks.values.compactMap { track -> TrackedWire? in
            guard track.missedFrames == 0 else { return nil }
            return TrackedWire(
                id: track.id,
                contour: track.lastContour,
                velocity: track.velocity,
                ageFrames: track.ageFrames,
                trackingConfidence: track.trackingConfidence
            )
        }
    }

    // MARK: - Greedy IOU Matching

    /// Matches new contours to existing tracks by highest IOU, greedily.
    ///
    /// Returns pairs of `(trackID, contourIndex)` where IOU exceeds threshold.
    private func greedyMatch(
        newEntries: [(contour: WireContour, bbox: CGRect, center: CGPoint)]
    ) -> [(UUID, Int)] {
        guard !activeTracks.isEmpty, !newEntries.isEmpty else { return [] }

        // Build scored pairs
        var candidates: [(trackID: UUID, contourIndex: Int, iou: Float)] = []
        for (trackID, track) in activeTracks {
            for (index, entry) in newEntries.enumerated() {
                let score = Self.iou(track.lastBBox, entry.bbox)
                if score >= config.iouThreshold {
                    candidates.append((trackID, index, score))
                }
            }
        }

        // Sort by IOU descending — greedy picks highest first
        candidates.sort { $0.iou > $1.iou }

        var usedTracks: Set<UUID> = []
        var usedContours: Set<Int> = []
        var matches: [(UUID, Int)] = []

        for candidate in candidates {
            if usedTracks.contains(candidate.trackID) || usedContours.contains(candidate.contourIndex) {
                continue
            }
            matches.append((candidate.trackID, candidate.contourIndex))
            usedTracks.insert(candidate.trackID)
            usedContours.insert(candidate.contourIndex)
        }

        return matches
    }

    // MARK: - Geometry Helpers

    /// Computes axis-aligned bounding box for a contour's path.
    static func boundingBox(for contour: WireContour) -> CGRect {
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

    /// Computes Intersection Over Union for two rectangles.
    ///
    /// Returns 0 if the rectangles do not overlap.
    static func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection = a.intersection(b)
        if intersection.isNull { return 0.0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        guard unionArea > 0 else { return 0.0 }
        return Float(intersectionArea / unionArea)
    }
}

// MARK: - TrackState

extension WireTracker {
    /// Internal mutable state for an active wire track.
    struct TrackState {
        let id: UUID
        var lastContour: WireContour
        var lastBBox: CGRect
        var lastCenter: CGPoint
        var velocity: CGVector
        var ageFrames: Int
        var missedFrames: Int
        var trackingConfidence: Float
    }
}
