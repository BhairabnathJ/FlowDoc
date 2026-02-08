import Foundation

// MARK: - CoordinateMappingEngine

/// Protocol for mapping tracked wires to logical grid connections.
///
/// Takes `[TrackedWire]` from Agent 2 and returns `[MappedConnection]`
/// with human-readable labels (e.g. "Row 12F") and confidence scores.
///
/// The v1 implementation (`CoordinateMapper`) uses manual 4-corner calibration
/// and a perspective homography to map wire endpoints onto a breadboard grid.
protocol CoordinateMappingEngine {
    /// Maps tracked wires to logical grid connections.
    ///
    /// - Parameter wires: Tracked wires with stable IDs from Agent 2
    /// - Returns: Mapped connections with labeled endpoints and confidence scores
    func mapToGrid(_ wires: [TrackedWire]) async throws -> [MappedConnection]
}
