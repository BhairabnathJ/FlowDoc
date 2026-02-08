import Foundation
import Vision
import AVFoundation
import CoreGraphics

// MARK: - VisionFrameworkDetector

/// Wire detection implementation using Apple's Vision framework.
///
/// Uses `VNDetectContoursRequest` (iOS 14+) to find contour shapes
/// in camera frames, then filters and scores them to identify wire-like objects.
///
/// Marked `nonisolated` to opt out of the project-wide `@MainActor` default —
/// Vision processing is CPU-intensive and must run off the main thread.
///
/// Detection pipeline:
/// 1. Validate pixel buffer format
/// 2. Run Vision contour detection
/// 3. Extract points from CGPath
/// 4. Filter by geometry (length, aspect ratio, thickness)
/// 5. Simplify with Ramer-Douglas-Peucker
/// 6. Score confidence (length 40%, aspect 40%, straightness 20%)
nonisolated final class VisionFrameworkDetector: WireDetectionEngine {
    private let config: WireDetectionConfig

    /// Creates a detector with the given configuration.
    ///
    /// - Parameter config: Detection thresholds and weights
    init(config: WireDetectionConfig) {
        self.config = config
    }

    // MARK: - WireDetectionEngine

    func detectWires(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        timestamp: Date
    ) async throws -> [WireContour] {
        // 1. Validate pixel format
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard pixelFormat == kCVPixelFormatType_32BGRA else {
            throw CircuitCameraError.unsupportedPixelFormat
        }

        // 2. Configure Vision request
        let request = VNDetectContoursRequest()
        request.revision = VNDetectContourRequestRevision1
        request.contrastAdjustment = config.contrastAdjustment
        request.detectsDarkOnLight = config.detectsDarkOnLight
        request.maximumImageDimension = config.maximumImageDimension

        // 3. Run detection
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            throw CircuitCameraError.visionProcessingFailed(error.localizedDescription)
        }

        guard let observations = request.results, !observations.isEmpty else {
            return []
        }

        // 4. Process each contour observation
        let imageDim = Float(config.maximumImageDimension)
        let rdpEpsilon = config.rdpEpsilonRatio * imageDim
        var contours: [WireContour] = []

        for observation in observations {
            let topLevelCount = observation.topLevelContourCount
            for i in 0..<topLevelCount {
                guard let contour = try? observation.contour(at: IndexPath(index: i)) else {
                    continue
                }
                processContour(
                    contour,
                    imageDim: imageDim,
                    rdpEpsilon: rdpEpsilon,
                    timestamp: timestamp,
                    into: &contours
                )
            }
        }

        return contours
    }

    // MARK: - Contour Processing Pipeline

    /// Processes a single VNContour through the filter/simplify/score pipeline.
    private func processContour(
        _ contour: VNContour,
        imageDim: Float,
        rdpEpsilon: Float,
        timestamp: Date,
        into results: inout [WireContour]
    ) {
        // Extract points from CGPath
        let rawPoints = extractPoints(from: contour)

        // Filter by geometry
        guard let metrics = filterMetrics(for: rawPoints, imageDim: imageDim) else {
            return
        }

        // RDP simplification
        let simplified = simplifyRDP(rawPoints, epsilon: rdpEpsilon / imageDim)

        // Ensure minimum point count after simplification
        guard simplified.count >= config.minPointCount else { return }

        // Compute straightness and confidence
        let straightness = computeStraightness(simplified)
        let confidence = computeConfidence(
            pixelLength: metrics.pixelLength,
            aspectRatio: metrics.aspectRatio,
            straightness: straightness
        )

        let wireContour = WireContour(
            id: UUID(),
            path: simplified,
            confidence: confidence,
            colorHint: nil,
            timestamp: timestamp,
            metadata: ContourMetadata(
                pixelLength: metrics.pixelLength,
                aspectRatio: metrics.aspectRatio,
                straightnessScore: straightness,
                pointCount: simplified.count
            )
        )
        results.append(wireContour)
    }

    // MARK: - Point Extraction (Spec 2.3.3)

    /// Extracts discrete points from a VNContour's normalized CGPath.
    ///
    /// Handles all CGPath element types: moveToPoint, addLineToPoint,
    /// addQuadCurveToPoint (endpoint), addCurveToPoint (endpoint).
    private func extractPoints(from contour: VNContour) -> [CGPoint] {
        let path = contour.normalizedPath
        var points: [CGPoint] = []

        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            switch element.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.points[0])
            case .addQuadCurveToPoint:
                points.append(element.points[1])
            case .addCurveToPoint:
                points.append(element.points[2])
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }

        return points
    }

    // MARK: - Contour Filtering (Spec 2.3.4)

    /// Geometric metrics extracted during filtering.
    private struct ContourFilterMetrics {
        let pixelLength: Float
        let aspectRatio: Float
        let thickness: Float
    }

    /// Computes geometric metrics and checks filter thresholds.
    ///
    /// Returns `nil` if the contour fails any filter criterion.
    private func filterMetrics(for points: [CGPoint], imageDim: Float) -> ContourFilterMetrics? {
        // Minimum point count
        guard points.count >= config.minPointCount else { return nil }

        // Bounding box in normalized coords
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude

        for point in points {
            let px = Float(point.x)
            let py = Float(point.y)
            minX = min(minX, px)
            maxX = max(maxX, px)
            minY = min(minY, py)
            maxY = max(maxY, py)
        }

        let bboxWidth = (maxX - minX) * imageDim
        let bboxHeight = (maxY - minY) * imageDim

        // Pixel length = longer dimension of bounding box
        let pixelLength = max(bboxWidth, bboxHeight)
        guard pixelLength >= config.minPixelLength else { return nil }

        // Thickness = shorter dimension
        let thickness = min(bboxWidth, bboxHeight)

        // Aspect ratio
        let aspectRatio = pixelLength / max(thickness, 1.0)
        guard aspectRatio >= config.minAspectRatio else { return nil }

        // Max thickness check
        let maxThickness = imageDim * config.maxThicknessRatio
        guard thickness <= maxThickness else { return nil }

        return ContourFilterMetrics(
            pixelLength: pixelLength,
            aspectRatio: aspectRatio,
            thickness: thickness
        )
    }

    // MARK: - RDP Simplification (Spec 2.3.5)

    /// Simplifies a path using the Ramer-Douglas-Peucker algorithm.
    ///
    /// Reduces point count while preserving overall shape within `epsilon` tolerance.
    /// - Parameters:
    ///   - points: Input path points (normalized coordinates)
    ///   - epsilon: Maximum allowed perpendicular distance for simplification
    /// - Returns: Simplified path
    private func simplifyRDP(_ points: [CGPoint], epsilon: Float) -> [CGPoint] {
        guard points.count > 2 else { return points }

        let first = points[0]
        let last = points[points.count - 1]

        var maxDist: Float = 0
        var maxIndex = 0

        for i in 1..<points.count - 1 {
            let dist = perpendicularDistance(points[i], lineStart: first, lineEnd: last)
            if dist > maxDist {
                maxDist = dist
                maxIndex = i
            }
        }

        if maxDist > epsilon {
            let left = simplifyRDP(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = simplifyRDP(Array(points[maxIndex..<points.count]), epsilon: epsilon)
            return left.dropLast() + right
        } else {
            return [first, last]
        }
    }

    /// Computes perpendicular distance from a point to a line segment.
    private func perpendicularDistance(
        _ point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> Float {
        let dx = Float(lineEnd.x - lineStart.x)
        let dy = Float(lineEnd.y - lineStart.y)
        let norm = sqrt(dx * dx + dy * dy)

        if norm < 1e-6 {
            return hypot(Float(point.x - lineStart.x), Float(point.y - lineStart.y))
        }

        let t = max(0, min(1, (Float(point.x - lineStart.x) * dx + Float(point.y - lineStart.y) * dy) / (norm * norm)))
        let projX = Float(lineStart.x) + t * dx
        let projY = Float(lineStart.y) + t * dy

        return hypot(Float(point.x) - projX, Float(point.y) - projY)
    }

    // MARK: - Confidence Scoring (Spec 2.3.6)

    /// Computes a weighted confidence score for a detected contour.
    ///
    /// Weights: length 40%, aspect ratio 40%, straightness 20%.
    /// Each component is normalized to 0-1 before weighting.
    private func computeConfidence(
        pixelLength: Float,
        aspectRatio: Float,
        straightness: Float
    ) -> Float {
        let lengthScore = min(1.0, pixelLength / 500.0)
        let aspectScore = min(1.0, aspectRatio / 20.0)
        let straightScore = straightness

        let confidence =
            lengthScore * config.weightLength +
            aspectScore * config.weightAspectRatio +
            straightScore * config.weightStraightness

        return min(1.0, max(0.0, confidence))
    }

    /// Computes straightness as the ratio of direct distance to path length.
    ///
    /// Returns 1.0 for a perfectly straight line, lower for curves.
    private func computeStraightness(_ points: [CGPoint]) -> Float {
        guard points.count >= 2 else { return 0 }

        let first = points[0]
        let last = points[points.count - 1]
        let directDist = hypot(Float(last.x - first.x), Float(last.y - first.y))

        var pathLength: Float = 0
        for i in 0..<points.count - 1 {
            let dx = Float(points[i + 1].x - points[i].x)
            let dy = Float(points[i + 1].y - points[i].y)
            pathLength += hypot(dx, dy)
        }

        return pathLength > 0 ? directDist / pathLength : 0
    }
}
