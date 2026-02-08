import Foundation
import CoreGraphics

// MARK: - Homography

/// A 3×3 perspective transform matrix for mapping between coordinate systems.
///
/// Stored as a flat 9-element array in row-major order:
/// ```
/// [ m00 m01 m02 ]
/// [ m10 m11 m12 ]
/// [ m20 m21 m22 ]
/// ```
struct Homography: Equatable {
    let m: [CGFloat] // 9 elements, row-major

    /// Applies the perspective transform to a point using homogeneous coordinates.
    ///
    /// - Parameter point: Source point
    /// - Returns: Transformed point (after dividing by w)
    func transform(_ point: CGPoint) -> CGPoint {
        let x = m[0] * point.x + m[1] * point.y + m[2]
        let y = m[3] * point.x + m[4] * point.y + m[5]
        let w = m[6] * point.x + m[7] * point.y + m[8]
        guard abs(w) > 1e-10 else { return point }
        return CGPoint(x: x / w, y: y / w)
    }

    /// Computes the inverse transform, or `nil` if the matrix is singular.
    func inverted() -> Homography? {
        // 3×3 matrix inverse via cofactors
        let a = m[0], b = m[1], c = m[2]
        let d = m[3], e = m[4], f = m[5]
        let g = m[6], h = m[7], i = m[8]

        let det = a * (e * i - f * h)
                - b * (d * i - f * g)
                + c * (d * h - e * g)
        guard abs(det) > 1e-10 else { return nil }

        let invDet = 1.0 / det
        return Homography(m: [
            (e * i - f * h) * invDet,
            (c * h - b * i) * invDet,
            (b * f - c * e) * invDet,
            (f * g - d * i) * invDet,
            (a * i - c * g) * invDet,
            (c * d - a * f) * invDet,
            (d * h - e * g) * invDet,
            (b * g - a * h) * invDet,
            (a * e - b * d) * invDet
        ])
    }
}

// MARK: - CoordinateMapper

/// Maps tracked wire endpoints to breadboard hole labels using perspective calibration.
///
/// The user provides 4 breadboard corner points in Vision coordinates.
/// A perspective homography transforms wire endpoints from Vision space
/// to canonical board space (0...1), where they are snapped to the nearest
/// breadboard hole.
///
/// **Usage:**
/// 1. Call `calibrate(corners:)` with 4 Vision-space corner taps
/// 2. Call `mapToGrid(_:)` each frame with tracked wires
final class CoordinateMapper: CoordinateMappingEngine {

    /// Snap threshold in canonical board-space distance.
    /// Endpoints farther than this from any hole are rejected.
    private let snapThreshold: CGFloat = 0.02

    /// Minimum confidence to include a mapped connection.
    private let confidenceCutoff: Float = 0.4

    /// Quality score for the current calibration (0...1).
    private var calibrationConfidence: Float = 0.0

    private let grid: BreadboardGrid

    /// Vision → board-space transform
    private var homography: Homography?

    /// Board-space → Vision transform (for producing output positions)
    private var inverseHomography: Homography?

    /// Whether the mapper has been calibrated with 4 corner points.
    var isCalibrated: Bool { homography != nil }

    /// Creates a coordinate mapper with the given breadboard grid.
    ///
    /// - Parameter grid: Breadboard grid model (default: standard 830-point)
    init(grid: BreadboardGrid = .standard) {
        self.grid = grid
    }

    // MARK: - Calibration

    /// Calibrates the mapper using 4 breadboard corner points in Vision coordinates.
    ///
    /// Corner order: bottom-left, bottom-right, top-right, top-left.
    /// Computes a perspective transform mapping Vision coords to canonical board coords.
    ///
    /// - Parameter corners: Exactly 4 corner points in Vision normalized coordinates
    func calibrate(corners: [CGPoint]) {
        guard corners.count == 4 else {
            homography = nil
            inverseHomography = nil
            calibrationConfidence = 0
            return
        }

        // Source: user-tapped corners in Vision space
        // Destination: canonical board corners
        let dst: [CGPoint] = [
            CGPoint(x: 0, y: 0), // bottom-left
            CGPoint(x: 1, y: 0), // bottom-right
            CGPoint(x: 1, y: 1), // top-right
            CGPoint(x: 0, y: 1)  // top-left
        ]

        homography = Self.computeHomography(from: corners, to: dst)
        inverseHomography = homography?.inverted()

        // Estimate calibration quality from how quadrilateral the corners are
        calibrationConfidence = Self.estimateCalibrationQuality(corners)
    }

    /// Clears the current calibration.
    func resetCalibration() {
        homography = nil
        inverseHomography = nil
        calibrationConfidence = 0
    }

    // MARK: - CoordinateMappingEngine

    /// Maps tracked wires to breadboard connections.
    ///
    /// For each wire, extracts the first and last path points as endpoints,
    /// transforms them to board space, snaps to the nearest hole, and
    /// produces a `MappedConnection` with confidence scoring.
    ///
    /// - Parameter wires: Tracked wires from Agent 2
    /// - Returns: Mapped connections for wires whose endpoints map to known holes
    func mapToGrid(_ wires: [TrackedWire]) async throws -> [MappedConnection] {
        guard let h = homography, let invH = inverseHomography else { return [] }

        var connections: [MappedConnection] = []
        connections.reserveCapacity(wires.count)

        for wire in wires {
            guard let startVision = wire.contour.path.first,
                  let endVision = wire.contour.path.last,
                  wire.contour.path.count >= 2 else { continue }

            // Transform endpoints: Vision → board canonical space
            let startBoard = h.transform(startVision)
            let endBoard = h.transform(endVision)

            // Check if endpoints are within board bounds (with small margin)
            let margin: CGFloat = -0.05
            let boardBounds = CGRect(x: margin, y: margin,
                                     width: 1.0 - 2 * margin,
                                     height: 1.0 - 2 * margin)
            guard boardBounds.contains(startBoard),
                  boardBounds.contains(endBoard) else { continue }

            // Snap to nearest holes
            guard let (startHole, startDist) = grid.nearestHole(to: startBoard),
                  let (endHole, endDist) = grid.nearestHole(to: endBoard) else { continue }

            // Reject if too far from any hole
            guard startDist <= snapThreshold,
                  endDist <= snapThreshold else { continue }

            // Confidence scoring
            let maxDist = max(startDist, endDist)
            let distanceScore = Float(max(min(1.0 - 25.0 * maxDist, 1.0), 0.0))
            let confidence = 0.7 * distanceScore + 0.3 * calibrationConfidence

            guard confidence >= confidenceCutoff else { continue }

            // Build nodes — positions in Vision space (as per SHARED-MODELS.md)
            let startNode = Node(
                type: startHole.isPowerRail ? .breadboardHole : .breadboardHole,
                label: grid.label(for: startHole),
                position: invH.transform(startHole.canonicalPosition)
            )
            let endNode = Node(
                type: endHole.isPowerRail ? .breadboardHole : .breadboardHole,
                label: grid.label(for: endHole),
                position: invH.transform(endHole.canonicalPosition)
            )

            connections.append(MappedConnection(
                id: UUID(),
                wireID: wire.id,
                startNode: startNode,
                endNode: endNode,
                confidence: confidence
            ))
        }

        return connections
    }

    // MARK: - Homography Computation

    /// Computes a 3×3 perspective homography from 4 point correspondences
    /// using the Direct Linear Transform (DLT) method.
    ///
    /// Solves the 8×8 linear system via Gaussian elimination.
    ///
    /// - Parameters:
    ///   - src: 4 source points
    ///   - dst: 4 destination points
    /// - Returns: The computed homography, or `nil` if the system is degenerate
    private static func computeHomography(from src: [CGPoint], to dst: [CGPoint]) -> Homography? {
        guard src.count == 4, dst.count == 4 else { return nil }

        // Build 8×9 matrix for Ah = 0, then solve the 8×8 system
        // by setting h[8] = 1 and rearranging to Ax = b form.
        //
        // For each correspondence (x,y) → (u,v):
        //   x*h0 + y*h1 + h2 - x*u*h6 - y*u*h7 = u
        //   x*h3 + y*h4 + h5 - x*v*h6 - y*v*h7 = v

        var a = [[CGFloat]](repeating: [CGFloat](repeating: 0, count: 8), count: 8)
        var b = [CGFloat](repeating: 0, count: 8)

        for i in 0..<4 {
            let x = src[i].x, y = src[i].y
            let u = dst[i].x, v = dst[i].y

            let row1 = i * 2
            let row2 = i * 2 + 1

            a[row1][0] = x; a[row1][1] = y; a[row1][2] = 1
            a[row1][3] = 0; a[row1][4] = 0; a[row1][5] = 0
            a[row1][6] = -x * u; a[row1][7] = -y * u
            b[row1] = u

            a[row2][0] = 0; a[row2][1] = 0; a[row2][2] = 0
            a[row2][3] = x; a[row2][4] = y; a[row2][5] = 1
            a[row2][6] = -x * v; a[row2][7] = -y * v
            b[row2] = v
        }

        // Gaussian elimination with partial pivoting
        for col in 0..<8 {
            // Find pivot
            var maxVal: CGFloat = 0
            var maxRow = col
            for row in col..<8 {
                if abs(a[row][col]) > maxVal {
                    maxVal = abs(a[row][col])
                    maxRow = row
                }
            }
            guard maxVal > 1e-10 else { return nil }

            // Swap rows
            if maxRow != col {
                a.swapAt(col, maxRow)
                b.swapAt(col, maxRow)
            }

            // Eliminate below
            for row in (col + 1)..<8 {
                let factor = a[row][col] / a[col][col]
                for k in col..<8 {
                    a[row][k] -= factor * a[col][k]
                }
                b[row] -= factor * b[col]
            }
        }

        // Back substitution
        var h = [CGFloat](repeating: 0, count: 8)
        for row in stride(from: 7, through: 0, by: -1) {
            var sum = b[row]
            for col in (row + 1)..<8 {
                sum -= a[row][col] * h[col]
            }
            guard abs(a[row][row]) > 1e-10 else { return nil }
            h[row] = sum / a[row][row]
        }

        return Homography(m: [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1.0])
    }

    /// Estimates calibration quality from the shape of the tapped quadrilateral.
    ///
    /// A well-formed quadrilateral (near-rectangular, reasonable area) scores higher.
    private static func estimateCalibrationQuality(_ corners: [CGPoint]) -> Float {
        // Compute area using shoelace formula
        var area: CGFloat = 0
        for i in 0..<4 {
            let j = (i + 1) % 4
            area += corners[i].x * corners[j].y
            area -= corners[j].x * corners[i].y
        }
        area = abs(area) / 2.0

        // Reasonable breadboard should cover 5–80% of the frame
        let areaScore: Float
        if area < 0.01 {
            areaScore = 0.1
        } else if area > 0.9 {
            areaScore = 0.5
        } else {
            areaScore = Float(min(area / 0.15, 1.0))
        }

        // Check that all 4 sides have reasonable length (not degenerate)
        var minSide = CGFloat.greatestFiniteMagnitude
        var maxSide: CGFloat = 0
        for i in 0..<4 {
            let j = (i + 1) % 4
            let dx = corners[j].x - corners[i].x
            let dy = corners[j].y - corners[i].y
            let len = sqrt(dx * dx + dy * dy)
            minSide = min(minSide, len)
            maxSide = max(maxSide, len)
        }

        let ratioScore: Float = maxSide > 1e-6 ? Float(min(minSide / maxSide * 2.0, 1.0)) : 0.0

        return min((areaScore + ratioScore) / 2.0, 1.0)
    }
}
