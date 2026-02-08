# Shared Data Models - Circuit Camera Module

**Last Updated:** February 8, 2026  
**Status:** Agent 1 Active

---

## Purpose

This file defines the **exact data model contracts** that all Circuit Camera agents must use. Every agent MUST read this file first to ensure type compatibility.

---

## Coordinate System Standard

**ALL models use Vision framework normalized coordinates:**

- **Origin:** Bottom-left (0, 0)
- **X-axis:** Left → Right (0 → 1)
- **Y-axis:** Bottom → Top (0 → 1)
- **Orientation:** Portrait-up relative to sensor

**Conversion to UIKit (Agent 4 only):**
```swift
let uiPoint = CGPoint(
    x: visionPoint.x,
    y: 1.0 - visionPoint.y  // Flip Y-axis
)
```

---

## Agent 1 Output: WireContour

**Owner:** Agent 1 (Wire Detection)  
**Consumers:** Agent 2 (Tracking), Agent 4 (Rendering)

```swift
struct WireContour: Identifiable, Codable, Equatable {
    let id: UUID                     // New UUID per frame
    let path: [CGPoint]              // Vision normalized coords
    let confidence: Float            // 0.0-1.0
    let colorHint: RGB?              // Optional in v1
    let timestamp: Date              // Frame timestamp
    let metadata: ContourMetadata
}

struct RGB: Codable, Equatable {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

struct ContourMetadata: Codable, Equatable {
    let pixelLength: Float           // Before normalization
    let aspectRatio: Float           // Length / thickness
    let straightnessScore: Float     // 0-1
    let pointCount: Int              // After simplification
}
```

**Rules:**
- `path` must have ≥8 points
- `path` points must be in range [0.0, 1.0]
- `confidence` must be in range [0.0, 1.0]
- `timestamp` must match frame capture time

---

## Agent 2 Output: TrackedWire

**Owner:** Agent 2 (Wire Tracking)  
**Consumers:** Agent 3 (Mapping), Agent 4 (Rendering), Agent 5 (Persistence)

```swift
struct TrackedWire: Identifiable, Codable, Equatable {
    let id: UUID                     // STABLE across frames
    let contour: WireContour         // Current frame detection
    let velocity: CGVector           // Estimated motion (normalized/sec)
    let ageFrames: Int               // Frames since first detection
    let trackingConfidence: Float    // 0.0-1.0 (tracking quality)
}
```

**Rules:**
- `id` must remain stable across frames (IOU matching)
- `velocity` in normalized coordinates per second
- `ageFrames` increments each frame wire is tracked
- `trackingConfidence` separate from detection confidence

---

## Agent 3 Output: MappedConnection

**Owner:** Agent 3 (Coordinate Mapping)  
**Consumers:** Agent 4 (Rendering), Agent 5 (Persistence)

```swift
struct MappedConnection: Identifiable, Codable, Equatable {
    let id: UUID
    let wireID: UUID                 // References TrackedWire.id
    let startNode: Node
    let endNode: Node
    let confidence: Float            // 0.0-1.0 (mapping confidence)
}

struct Node: Codable, Equatable {
    let type: NodeType
    let label: String                // "Row 12F", "GPIO23", etc.
    let position: CGPoint            // Vision normalized coords
}

enum NodeType: String, Codable {
    case breadboardHole              // Standard breadboard hole
    case devPin                      // Dev board pin (ESP32, etc.)
    case modulePin                   // Module/sensor pin
    case unknown                     // Unmapped endpoint
}
```

**Rules:**
- `wireID` must reference valid `TrackedWire.id`
- `label` format depends on `NodeType`:
  - `.breadboardHole`: "Row 12F", "Power +" format
  - `.devPin`: "GPIO23", "3V3", "GND" format
  - `.modulePin`: "VCC", "SDA", "SCL" format
- `position` matches wire endpoint coordinates

---

## Agent 4 Output: Overlay Rendering (No Model)

**Owner:** Agent 4 (Overlay Rendering)  
**Consumers:** User (visual only)

Agent 4 does NOT create new data models. It consumes:
- `TrackedWire` from Agent 2
- `MappedConnection` from Agent 3

And renders CALayer overlays on camera view.

---

## Agent 5 Output: CircuitSnapshot

**Owner:** Agent 5 (Snapshot Persistence)  
**Consumers:** DatabaseManager, Export system

```swift
struct CircuitSnapshot: Identifiable, Codable {
    let id: UUID
    let sessionID: UUID              // References Session.id
    let timestamp: Date
    let frameImage: Data             // JPEG compressed
    let wires: [TrackedWire]
    let connections: [MappedConnection]
    let metadata: SnapshotMetadata
}

struct SnapshotMetadata: Codable {
    let deviceModel: String          // "iPhone 11 Pro"
    let detectionFPS: Float          // Measured FPS at capture
    let wireCount: Int               // wires.count
    let mappedCount: Int             // connections.count
    let captureQuality: CaptureQuality
}

enum CaptureQuality: String, Codable {
    case high                        // Good lighting, stable camera
    case medium                      // Acceptable conditions
    case low                         // Poor lighting or motion blur
}
```

**Rules:**
- `sessionID` must reference existing Session
- `frameImage` JPEG quality: 0.8
- `wires` and `connections` must be from same frame
- `metadata` populated at capture time

---

## Configuration Models

### WireDetectionConfig (Agent 1)

```swift
struct WireDetectionConfig: Codable, Equatable {
    var maximumImageDimension: Int
    var contrastAdjustment: Float
    var detectsDarkOnLight: Bool
    var minPixelLength: Float
    var minAspectRatio: Float
    var maxThicknessRatio: Float
    var minPointCount: Int
    var rdpEpsilonRatio: Float
    var enableColorSampling: Bool
    var weightLength: Float
    var weightAspectRatio: Float
    var weightStraightness: Float
    var targetFPS: Double
    var maxProcessingTimeMs: Double
    
    static func deviceDefault() -> WireDetectionConfig
}
```

### WireTrackingConfig (Agent 2 - Future)

```swift
struct WireTrackingConfig: Codable, Equatable {
    var iouThreshold: Float          // 0.3 recommended
    var maxMissingFrames: Int        // 15 frames = 1 sec
    var velocitySmoothingFactor: Float
    var minTrackingConfidence: Float
}
```

---

## Protocol Definitions

### WireDetectionEngine (Agent 1)

```swift
protocol WireDetectionEngine {
    func detectWires(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        timestamp: Date
    ) async throws -> [WireContour]
}
```

### WireTrackingEngine (Agent 2 - Future)

```swift
protocol WireTrackingEngine {
    func updateTracking(
        with contours: [WireContour]
    ) async -> [TrackedWire]
}
```

### CoordinateMappingEngine (Agent 3 - Future)

```swift
protocol CoordinateMappingEngine {
    func mapToGrid(
        _ wires: [TrackedWire]
    ) async throws -> [MappedConnection]
}
```

---

## Error Types

```swift
enum CircuitCameraError: Error, LocalizedError {
    case visionProcessingFailed(String)
    case invalidPixelBuffer
    case unsupportedPixelFormat
    case trackingFailed(String)
    case mappingFailed(String)
    case snapshotCaptureFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .visionProcessingFailed(let msg):
            return "Vision processing failed: \(msg)"
        case .invalidPixelBuffer:
            return "Invalid or corrupted pixel buffer"
        case .unsupportedPixelFormat:
            return "Unsupported pixel format (expected BGRA)"
        case .trackingFailed(let msg):
            return "Wire tracking failed: \(msg)"
        case .mappingFailed(let msg):
            return "Coordinate mapping failed: \(msg)"
        case .snapshotCaptureFailed(let msg):
            return "Snapshot capture failed: \(msg)"
        }
    }
}
```

---

## Version History

| Version | Date | Agent | Change |
|---------|------|-------|--------|
| 1.0 | 2026-02-08 | Agent 1 | Initial models: WireContour, WireDetectionConfig |
| 1.1 | TBD | Agent 2 | Add: TrackedWire, WireTrackingConfig |
| 1.2 | TBD | Agent 3 | Add: MappedConnection, Node, NodeType |
| 1.3 | TBD | Agent 5 | Add: CircuitSnapshot, SnapshotMetadata |

---

## Agent Implementation Checklist

**Before starting your agent, verify:**

- [ ] Read this file completely
- [ ] Understand your input/output models
- [ ] Coordinate system matches (Vision bottom-left origin)
- [ ] Your spec references correct model versions
- [ ] Test data uses these exact types

**When your agent completes:**

- [ ] Update version history in this file
- [ ] Document any model changes/additions
- [ ] Notify next agent of new available types
- [ ] Verify backwards compatibility

---

**All agents: This is your source of truth for data contracts!**
