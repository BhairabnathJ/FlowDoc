import Foundation

// MARK: - FrameThrottle

/// Time-based frame throttle for Vision processing.
///
/// Limits frame processing to a target FPS (default 15) to balance
/// detection responsiveness with CPU/battery usage. Uses its own
/// actor isolation — safe to call from any context.
///
/// Usage:
/// ```swift
/// let throttle = FrameThrottle(targetFPS: 15.0)
/// if await throttle.shouldProcess(timestamp: frameTime) {
///     let contours = try await detector.detectWires(in: buffer, ...)
/// }
/// ```
actor FrameThrottle {
    private var lastProcessTime: Date = .distantPast
    private let minInterval: TimeInterval

    /// Creates a throttle targeting the given frames per second.
    ///
    /// - Parameter targetFPS: Desired processing rate (default: 15.0)
    init(targetFPS: Double = 15.0) {
        self.minInterval = 1.0 / targetFPS
    }

    /// Returns whether enough time has elapsed to process another frame.
    ///
    /// Updates the internal timestamp when returning `true`.
    /// - Parameter timestamp: Current frame's capture time
    /// - Returns: `true` if the frame should be processed
    func shouldProcess(timestamp: Date) -> Bool {
        let elapsed = timestamp.timeIntervalSince(lastProcessTime)
        if elapsed >= minInterval {
            lastProcessTime = timestamp
            return true
        }
        return false
    }
}
