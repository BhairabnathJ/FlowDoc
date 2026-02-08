## **File 2:** `.claude/features/camera-module/01-wire-detection.md`

```markdown
# Feature: Wire Detection via Vision Framework

**Agent:** Agent 1 - Wire Detection  
**Status:** Ready for Implementation  
**Dependencies:** None (first component)  
**Estimated Complexity:** Medium  
**Last Updated:** February 8, 2026

---

## 1. OVERVIEW

### Purpose
Detect wires and cables in camera frames using Apple's Vision framework, outputting structured contour data for downstream tracking and mapping agents.

### Success Criteria
1. **Recall:** Detect ≥70% of visible wires in good lighting (500-800 lux)
2. **Performance:** Process frames at 15+ FPS on iPhone 11 Pro
3. **Latency:** <70ms per frame processing time (avg)
4. **Stability:** No crashes with edge cases (no wires, occlusions, varied lighting)
5. **Battery:** <5% drain per hour of continuous camera use

### Out of Scope (v1)
- ❌ Wire tracking across frames (Agent 2's responsibility)
- ❌ Coordinate mapping to breadboard/pins (Agent 3's responsibility)
- ❌ UI overlay rendering (Agent 4's responsibility)
- ❌ Custom ML model training (using Vision framework only)
- ❌ Color sampling (marked optional, can skip in v1)
- ❌ Cable type classification (HDMI vs power - future LLM feature)

---

## 2. TECHNICAL APPROACH

### 2.1 Architecture

```
AVCaptureSession (30 FPS)
    ↓
CVPixelBuffer + timestamp
    ↓
FrameThrottle (time-based, 15 FPS target)
    ↓ (if shouldProcess)
VNImageRequestHandler
    ↓
VNDetectContoursRequest
    ↓
[VNContoursObservation]
    ↓
ContourProcessor
    ↓ (filter + simplify + score)
[WireContour]
    ↓
Agent 2 (tracking)
```

**Key Design:** Pluggable detection engine protocol allows future CoreML swap

```swift
protocol WireDetectionEngine {
    func detectWires(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        timestamp: Date
    ) async throws -> [WireContour]
}

// v1 implementation
class VisionFrameworkDetector: WireDetectionEngine { ... }

// v2 future (CoreML with fine-tuned YOLO)
// class CoreMLDetector: WireDetectionEngine { ... }
```

---

### 2.2 Data Models

**Create `Models/CircuitCamera/WireContour.swift`:**

```swift
import Foundation
import CoreGraphics

/// A detected wire contour from a single camera frame.
/// Coordinates use Vision framework normalized space (bottom-left origin).
struct WireContour: Identifiable, Codable, Equatable {
    /// Unique identifier for this detection (new UUID per frame)
    let id: UUID
    
    /// Contour path in Vision normalized coordinates (0...1, bottom-left origin)
    /// - Origin: (0, 0) = bottom-left corner
    /// - X-axis: left→right (0→1)
    /// - Y-axis: bottom→top (0→1)
    let path: [CGPoint]
    
    /// Detection confidence score (0.0-1.0)
    /// Based on: length, aspect ratio, straightness
    let confidence: Float
    
    /// Optional dominant color hint (nil acceptable in v1)
    let colorHint: RGB?
    
    /// Frame timestamp for tracking correlation
    let timestamp: Date
    
    /// Metadata for debugging/optimization
    let metadata: ContourMetadata
}

/// RGB color representation
struct RGB: Codable, Equatable {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

/// Detection metadata for diagnostics
struct ContourMetadata: Codable, Equatable {
    let pixelLength: Float           // Before normalization
    let aspectRatio: Float           // Length / thickness
    let straightnessScore: Float     // 0-1, higher = straighter
    let pointCount: Int              // Points in simplified path
}
```

**Create `Models/CircuitCamera/WireDetectionConfig.swift`:**

```swift
import Foundation
import UIKit

/// Configuration for wire detection thresholds and performance.
struct WireDetectionConfig: Codable, Equatable {
    // Vision request settings
    var maximumImageDimension: Int
    var contrastAdjustment: Float
    var detectsDarkOnLight: Bool
    
    // Filtering thresholds (pixels, relative to maximumImageDimension)
    var minPixelLength: Float
    var minAspectRatio: Float
    var maxThicknessRatio: Float        // Scales with image dimension
    var minPointCount: Int
    
    // RDP simplification
    var rdpEpsilonRatio: Float          // Scales with image dimension
    
    // Color sampling (optional in v1)
    var enableColorSampling: Bool
    
    // Confidence scoring weights
    var weightLength: Float
    var weightAspectRatio: Float
    var weightStraightness: Float
    
    // Performance
    var targetFPS: Double
    var maxProcessingTimeMs: Double
    
    /// Device-specific defaults
    static func deviceDefault() -> WireDetectionConfig {
        let modelIdentifier = UIDevice.current.modelIdentifier
        
        let dimension: Int
        if modelIdentifier.contains("iPhone17") {
            dimension = 768
        } else if modelIdentifier.contains("iPhone15") || modelIdentifier.contains("iPhone16") {
            dimension = 640
        } else {
            dimension = 512  // iPhone 11-14
        }
        
        return WireDetectionConfig(
            maximumImageDimension: dimension,
            contrastAdjustment: 1.0,
            detectsDarkOnLight: false,  // Wires on white breadboard
            minPixelLength: 50.0,
            minAspectRatio: 5.0,
            maxThicknessRatio: 18.0 / 512.0,
            minPointCount: 8,
            rdpEpsilonRatio: 2.0 / 512.0,
            enableColorSampling: false,  // Skip in v1
            weightLength: 0.40,
            weightAspectRatio: 0.40,
            weightStraightness: 0.20,
            targetFPS: 15.0,
            maxProcessingTimeMs: 100.0
        )
    }
}

// Helper extension
extension UIDevice {
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
```

---

### 2.3 Algorithms

#### 2.3.1 Frame Throttling
Time-based throttling to achieve 15 FPS target:

```swift
actor FrameThrottle {
    private var lastProcessTime: Date = .distantPast
    private let minInterval: TimeInterval
    
    init(targetFPS: Double) {
        self.minInterval = 1.0 / targetFPS
    }
    
    func shouldProcess(timestamp: Date) -> Bool {
        let elapsed = timestamp.timeIntervalSince(lastProcessTime)
        if elapsed >= minInterval {
            lastProcessTime = timestamp
            return true
        }
        return false
    }
}
```

**Behavior:** If Vision takes 80ms, next frame processes 66ms after completion (~12 FPS). If Vision takes 30ms, achieves 15 FPS.

---

#### 2.3.2 Contour Detection via Vision

```swift
let request = VNDetectContoursRequest()
request.revision = VNDetectContoursRequestRevision2  // iOS 16+
request.contrastAdjustment = config.contrastAdjustment
request.detectsDarkOnLight = config.detectsDarkOnLight
request.maximumImageDimension = config.maximumImageDimension

let handler = VNImageRequestHandler(
    cvPixelBuffer: pixelBuffer,
    orientation: orientation,
    options: [:]
)

try handler.perform([request])

guard let observations = request.results as? [VNContoursObservation] else {
    return []
}

// Process each observation...
```

---

#### 2.3.3 Contour to Points Extraction

Vision provides `CGPath`, extract discrete points:

```swift
func extractPoints(from contour: VNContour) -> [CGPoint] {
    let path = contour.normalizedPath
    var points: [CGPoint] = []
    
    path.applyWithBlock { elementPtr in
        let element = elementPtr.pointee
        switch element.type {
        case .moveToPoint, .addLineToPoint:
            points.append(element.points)
        case .addQuadCurveToPoint:
            points.append(element.points)  // Endpoint [builder](https://www.builder.io/blog/claude-code)
        case .addCurveToPoint:
            points.append(element.points)  // Endpoint [blog.sshh](https://blog.sshh.io/p/how-i-use-every-claude-code-feature)
        case .closeSubpath:
            break
        @unknown default:
            break
        }
    }
    
    return points
}
```

---

#### 2.3.4 Contour Filtering

Filter out non-wire objects:

```swift
func shouldKeepContour(_ points: [CGPoint], config: WireDetectionConfig) -> Bool {
    // 1. Minimum point count
    guard points.count >= config.minPointCount else { return false }
    
    // 2. Compute pixel-space bounding box
    let bbox = boundingBox(for: points)
    let pixelLength = max(bbox.width, bbox.height) * Float(config.maximumImageDimension)
    
    // 3. Length threshold
    guard pixelLength >= config.minPixelLength else { return false }
    
    // 4. Aspect ratio (length / thickness)
    let thickness = min(bbox.width, bbox.height) * Float(config.maximumImageDimension)
    let aspectRatio = pixelLength / max(thickness, 1.0)
    guard aspectRatio >= config.minAspectRatio else { return false }
    
    // 5. Max thickness (exclude thick objects like boards)
    let maxThickness = Float(config.maximumImageDimension) * config.maxThicknessRatio
    guard thickness <= maxThickness else { return false }
    
    return true
}
```

---

#### 2.3.5 Ramer-Douglas-Peucker Simplification

Simplify path while preserving shape:

```swift
func simplifyRDP(_ points: [CGPoint], epsilon: Float) -> [CGPoint] {
    guard points.count > 2 else { return points }
    
    // Find point with max distance from line segment
    let first = points.first!
    let last = points.last!
    
    var maxDist: Float = 0
    var maxIndex = 0
    
    for i in 1..<points.count - 1 {
        let dist = perpendicularDistance(points[i], lineStart: first, lineEnd: last)
        if dist > maxDist {
            maxDist = dist
            maxIndex = i
        }
    }
    
    // If max distance > epsilon, recursively simplify
    if maxDist > epsilon {
        let left = simplifyRDP(Array(points[0...maxIndex]), epsilon: epsilon)
        let right = simplifyRDP(Array(points[maxIndex..<points.count]), epsilon: epsilon)
        return left.dropLast() + right
    } else {
        return [first, last]
    }
}

func perpendicularDistance(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Float {
    let dx = lineEnd.x - lineStart.x
    let dy = lineEnd.y - lineStart.y
    let norm = sqrt(dx * dx + dy * dy)
    
    if norm < 1e-6 { return hypot(Float(point.x - lineStart.x), Float(point.y - lineStart.y)) }
    
    let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (norm * norm)))
    let projX = lineStart.x + t * dx
    let projY = lineStart.y + t * dy
    
    return hypot(Float(point.x - projX), Float(point.y - projY))
}
```

---

#### 2.3.6 Confidence Scoring

```swift
func computeConfidence(
    pixelLength: Float,
    aspectRatio: Float,
    straightness: Float,
    config: WireDetectionConfig
) -> Float {
    // Normalize each component to 0-1
    let lengthScore = min(1.0, pixelLength / 500.0)  // Max out at 500px
    let aspectScore = min(1.0, aspectRatio / 20.0)   // Max out at 20:1
    let straightScore = straightness                  // Already 0-1
    
    // Weighted sum
    let confidence = 
        lengthScore * config.weightLength +
        aspectScore * config.weightAspectRatio +
        straightScore * config.weightStraightness
    
    return min(1.0, max(0.0, confidence))
}

func computeStraightness(_ points: [CGPoint]) -> Float {
    guard points.count >= 2 else { return 0 }
    
    let first = points.first!
    let last = points.last!
    let directDist = hypot(Float(last.x - first.x), Float(last.y - first.y))
    
    // Sum of segment lengths
    var pathLength: Float = 0
    for i in 0..<points.count - 1 {
        let dx = points[i+1].x - points[i].x
        let dy = points[i+1].y - points[i].y
        pathLength += hypot(Float(dx), Float(dy))
    }
    
    // Straightness = direct / path (1.0 = perfectly straight)
    return pathLength > 0 ? directDist / pathLength : 0
}
```

---

## 3. IMPLEMENTATION DETAILS

### 3.1 Files to Create

```
Services/CircuitCamera/
├── WireDetectionEngine.swift         # Protocol definition
├── VisionFrameworkDetector.swift     # v1 implementation
└── FrameThrottle.swift               # FPS throttling

Models/CircuitCamera/
├── WireContour.swift                 # Detection output
└── WireDetectionConfig.swift         # Configuration

Tests/CircuitCameraTests/
└── WireDetectionTests.swift          # Unit tests
```

### 3.2 Files NOT Modified (Agent 1 works independently)

- ❌ `CameraController.swift` - Agent 4 will integrate later
- ❌ `CircuitCameraView.swift` - Agent 4 creates this
- ❌ `DatabaseManager.swift` - Agent 5 modifies this

### 3.3 External Dependencies

- **Vision.framework** (iOS 16+, built-in)
- **AVFoundation.framework** (for CVPixelBuffer handling)
- **CoreGraphics.framework** (for geometry)

---

## 4. ACCEPTANCE CRITERIA

### Functional
- [ ] `VisionFrameworkDetector` conforms to `WireDetectionEngine` protocol
- [ ] Detects ≥70% of wires in `test-data/breadboard-good-light/` (n=50 wires)
- [ ] Returns empty array (no crash) when no wires present
- [ ] Returns low-confidence detections (not filtered) for manual inspection

### Performance
- [ ] Processes frames at 15+ FPS on iPhone 11 Pro (measured via XCTest performance test)
- [ ] Average latency <70ms per frame
- [ ] Memory usage <50MB during continuous operation
- [ ] No memory leaks detected in Instruments

### Data Quality
- [ ] All `WireContour` paths use Vision normalized coordinates (bottom-left origin)
- [ ] Confidence scores between 0.0-1.0
- [ ] RDP-simplified paths have ≥8 points
- [ ] Metadata fields populated correctly

### Error Handling
- [ ] Throws descriptive errors on Vision API failure
- [ ] Handles unsupported pixel formats gracefully (returns empty array)
- [ ] No crashes with corrupted/nil CVPixelBuffer

---

## 5. TESTING STRATEGY

### 5.1 Unit Tests

**File:** `Tests/CircuitCameraTests/WireDetectionTests.swift`

```swift
import XCTest
@testable import FlowDoc

class WireDetectionTests: XCTestCase {
    var detector: VisionFrameworkDetector!
    
    override func setUp() {
        super.setUp()
        detector = VisionFrameworkDetector(config: .deviceDefault())
    }
    
    func testDetectsWiresInGoodLighting() async throws {
        let pixelBuffer = loadTestImage("breadboard_good_light_01")
        let results = try await detector.detectWires(
            in: pixelBuffer,
            orientation: .up,
            timestamp: Date()
        )
        
        XCTAssertGreaterThanOrEqual(results.count, 7, "Should detect at least 7 of 10 wires")
    }
    
    func testReturnsEmptyArrayWhenNoWires() async throws {
        let pixelBuffer = loadTestImage("no_wires_blank")
        let results = try await detector.detectWires(
            in: pixelBuffer,
            orientation: .up,
            timestamp: Date()
        )
        
        XCTAssertEqual(results.count, 0)
    }
    
    func testCoordinatesUseVisionOrigin() async throws {
        let pixelBuffer = loadTestImage("breadboard_simple")
        let results = try await detector.detectWires(
            in: pixelBuffer,
            orientation: .up,
            timestamp: Date()
        )
        
        for contour in results {
            for point in contour.path {
                XCTAssertGreaterThanOrEqual(point.x, 0.0)
                XCTAssertLessThanOrEqual(point.x, 1.0)
                XCTAssertGreaterThanOrEqual(point.y, 0.0)
                XCTAssertLessThanOrEqual(point.y, 1.0)
            }
        }
    }
}
```

### 5.2 Performance Tests

```swift
func testFrameProcessingPerformance() async throws {
    let pixelBuffer = loadTestImage("breadboard_good_light_01")
    
    measure {
        let _ = try! await detector.detectWires(
            in: pixelBuffer,
            orientation: .up,
            timestamp: Date()
        )
    }
    
    // XCTest will report average time - should be <70ms
}
```

### 5.3 Test Data

**Location:** `FlowDoc/test-data/circuit-camera/`

**Required test images:**
- `breadboard-good-light/`: 5 images, 50 total labeled wires
- `breadboard-low-light/`: 3 images, 24 total labeled wires
- `no-wires/`: 2 images (blank breadboard, empty desk)
- `clutter/`: 2 images (hands, tools, non-wire objects)

**Ground truth format:** JSON with wire coordinates
```json
{
  "image": "breadboard_good_light_01.jpg",
  "wires": [
    {
      "id": 1,
      "color": "red",
      "start": [0.12, 0.34],
      "end": [0.58, 0.36]
    }
  ]
}
```

**Recall calculation:**
- Wire detected if any `WireContour` overlaps >30% of ground truth path
- Recall = detected / total_labeled

---

## 6. EDGE CASES & ERROR HANDLING

| Scenario | Expected Behavior |
|----------|-------------------|
| No wires visible | Return empty array `[]` |
| Low lighting (<50 lux) | Return low-confidence detections (don't filter) |
| Camera permission denied | Throw error (handled by CameraController) |
| Corrupted CVPixelBuffer | Throw `VisionError.invalidInput` |
| Vision API failure | Throw error with description, log to console |
| Processing timeout (>100ms) | Complete current frame, skip next frame if needed |
| Unsupported pixel format | Log warning, return empty array |
| Hand occlusion | Detect partial wires (acceptable) |
| Curved wires | Lower straightness score (acceptable) |
| Crossing wires | Detect as separate contours (correct behavior) |

---

## 7. DEPENDENCIES & COORDINATION

### Depends on:
- **None** (Agent 1 is first in pipeline)

### Blocks:
- **Agent 2** (Wire Tracking) needs `WireContour` output model
- **Agent 4** (Overlay Rendering) optionally uses Agent 1 output directly for basic mode

### Shared Interfaces:
- **Must match:** `.claude/SHARED-MODELS.md` `WireContour` definition
- **Coordinate system:** Vision normalized (bottom-left origin) - REQUIRED for Agent 2 compatibility

---

## 8. OPEN QUESTIONS

### Resolved (Decisions Made):
✅ **Coordinate system:** Vision normalized, bottom-left origin  
✅ **Color sampling:** Disabled in v1 (too complex, minimal value)  
✅ **iOS version:** Target iOS 16+ (per existing FlowDoc spec)  
✅ **Confidence filtering:** Return ALL detections, no filtering at Agent 1  
✅ **Pixel format:** Support BGRA, gracefully skip YUV (no conversion in v1)

### Remaining (Can implement without blocking):
- ⏳ **RDP epsilon tuning:** Start with 2.0px ratio, can adjust after testing
- ⏳ **Confidence weights:** Start with 40/40/20, tune based on real performance
- ⏳ **Curved wire handling:** Current straightness scoring handles this, may need adjustment

---

## 9. IMPLEMENTATION CHECKLIST

### Phase 1: Models & Protocol (Day 1)
- [ ] Create `WireContour.swift`
- [ ] Create `WireDetectionConfig.swift`
- [ ] Create `WireDetectionEngine.swift` protocol
- [ ] Verify builds with no errors

### Phase 2: Core Detection (Day 2-3)
- [ ] Create `VisionFrameworkDetector.swift`
- [ ] Implement `detectWires()` method
- [ ] Implement contour extraction from VNContoursObservation
- [ ] Implement filtering logic
- [ ] Implement RDP simplification
- [ ] Implement confidence scoring

### Phase 3: Throttling & Performance (Day 4)
- [ ] Create `FrameThrottle.swift`
- [ ] Integrate throttle into detection flow
- [ ] Add performance logging (optional)

### Phase 4: Testing (Day 5)
- [ ] Create test dataset (or use existing breadboard photo)
- [ ] Write unit tests
- [ ] Write performance tests
- [ ] Validate acceptance criteria
- [ ] Test on physical iPhone 11 Pro (if available)

### Phase 5: Documentation (Day 5)
- [ ] Add inline documentation to all public APIs
- [ ] Update `.claude/SHARED-MODELS.md` if any changes
- [ ] Document any deviations from this spec

---

## 10. NEXT AGENT HANDOFF

**Once Agent 1 is complete:**

Agent 2 (Wire Tracking) can begin implementation:
- Input: `[WireContour]` from Agent 1
- Task: Assign stable IDs across frames, track motion
- Spec: `.claude/features/camera-module/02-wire-tracking.md` (not created yet)

**Validation before handoff:**
- Agent 1 passes all acceptance criteria
- Test dataset shows ≥70% recall
- Performance meets 15 FPS target on test device

---
