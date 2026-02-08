import Foundation
import UIKit

// MARK: - WireDetectionConfig

/// Configuration for wire detection thresholds and performance tuning.
///
/// All filtering thresholds are relative to `maximumImageDimension`.
/// Use `deviceDefault()` for device-optimized defaults.
struct WireDetectionConfig: Codable, Equatable {
    // MARK: Vision Request Settings

    /// Maximum image dimension passed to VNDetectContoursRequest
    var maximumImageDimension: Int
    /// Contrast adjustment for contour detection (1.0 = no adjustment)
    var contrastAdjustment: Float
    /// Whether to detect dark contours on light background
    var detectsDarkOnLight: Bool

    // MARK: Filtering Thresholds

    /// Minimum pixel length to qualify as a wire
    var minPixelLength: Float
    /// Minimum length-to-thickness ratio (e.g. 5.0 = 5:1)
    var minAspectRatio: Float
    /// Maximum thickness ratio relative to image dimension
    var maxThicknessRatio: Float
    /// Minimum number of points in contour path
    var minPointCount: Int

    // MARK: RDP Simplification

    /// Ramer-Douglas-Peucker epsilon ratio (scales with image dimension)
    var rdpEpsilonRatio: Float

    // MARK: Color Sampling

    /// Whether to sample wire color (disabled in v1)
    var enableColorSampling: Bool

    // MARK: Confidence Scoring Weights

    /// Weight for pixel length in confidence score
    var weightLength: Float
    /// Weight for aspect ratio in confidence score
    var weightAspectRatio: Float
    /// Weight for straightness in confidence score
    var weightStraightness: Float

    // MARK: Performance

    /// Target frames per second for detection
    var targetFPS: Double
    /// Maximum processing time per frame in milliseconds
    var maxProcessingTimeMs: Double

    /// Returns device-optimized default configuration.
    ///
    /// Adjusts `maximumImageDimension` based on device capability:
    /// - iPhone 17 series: 768
    /// - iPhone 15/16 series: 640
    /// - Older devices (iPhone 11-14): 512
    static func deviceDefault() -> WireDetectionConfig {
        let modelIdentifier = UIDevice.current.modelIdentifier

        let dimension: Int
        if modelIdentifier.contains("iPhone17") {
            dimension = 768
        } else if modelIdentifier.contains("iPhone15") || modelIdentifier.contains("iPhone16") {
            dimension = 640
        } else {
            dimension = 512
        }

        return WireDetectionConfig(
            maximumImageDimension: dimension,
            contrastAdjustment: 1.0,
            detectsDarkOnLight: false,
            minPixelLength: 50.0,
            minAspectRatio: 5.0,
            maxThicknessRatio: 18.0 / 512.0,
            minPointCount: 8,
            rdpEpsilonRatio: 2.0 / 512.0,
            enableColorSampling: false,
            weightLength: 0.40,
            weightAspectRatio: 0.40,
            weightStraightness: 0.20,
            targetFPS: 15.0,
            maxProcessingTimeMs: 100.0
        )
    }
}

// MARK: - UIDevice Model Identifier

extension UIDevice {
    /// Hardware model identifier (e.g. "iPhone17,1").
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }
}
