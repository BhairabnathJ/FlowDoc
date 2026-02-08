import Foundation
import CoreGraphics

// MARK: - NodeType

/// Classification of a circuit connection endpoint.
///
/// Determines the label format and semantic meaning of a `Node`.
enum NodeType: String, Codable {
    /// Standard breadboard hole (label format: "Row 12F")
    case breadboardHole
    /// Dev board pin such as ESP32 (label format: "GPIO23", "3V3")
    case devPin
    /// Module or sensor pin (label format: "VCC", "SDA")
    case modulePin
    /// Unmapped endpoint outside any known grid
    case unknown
}

// MARK: - Node

/// A logical endpoint of a wire connection mapped to a known grid position.
///
/// Positions are in Vision normalized coordinates (bottom-left origin, 0...1).
struct Node: Codable, Equatable {
    /// What kind of connection point this node represents
    let type: NodeType
    /// Human-readable label (e.g. "Row 12F", "GPIO23", "Power +")
    let label: String
    /// Position in Vision normalized coordinates (bottom-left origin)
    let position: CGPoint
}

// MARK: - MappedConnection

/// A wire mapped to logical grid endpoints with confidence scoring.
///
/// Produced by Agent 3 (`CoordinateMapper`) from `TrackedWire` input.
/// Consumed by Agent 4 (overlay labels) and Agent 5 (persistence).
struct MappedConnection: Identifiable, Codable, Equatable {
    /// Unique identifier for this mapped connection
    let id: UUID
    /// References the source `TrackedWire.id`
    let wireID: UUID
    /// Logical start endpoint
    let startNode: Node
    /// Logical end endpoint
    let endNode: Node
    /// Mapping confidence (0.0–1.0), combining snap distance and calibration quality
    let confidence: Float
}
