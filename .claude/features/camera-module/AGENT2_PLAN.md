# Wire Tracking Implementation Plan (Agent 2)

**Created by:** Planner-FlowDoc
**Date:** 2026-02-08
**Depends on:** Agent 1 (WireContour, WireDetectionEngine — complete)

---

## Context

Agent 1 outputs `[WireContour]` with new UUIDs every frame. This means the same physical wire gets a different ID each frame, causing visual flicker. Agent 2 assigns **stable IDs** across frames using IOU (Intersection Over Union) bounding-box matching, producing `[TrackedWire]` for downstream agents.

---

## Files to Create

All paths relative to `/Users/theri/Documents/trials/FlowDoc/FlowDoc/FlowDoc/`

### 1. `Models/CircuitCamera/TrackedWire.swift` (~30 lines)
**Purpose:** Wire with stable ID persisting across frames
**Contains:** `TrackedWire` struct matching SHARED-MODELS.md exactly
**Dependencies:** Foundation, CoreGraphics (for CGVector)
**Conformances:** Identifiable, Codable, Equatable

```swift
struct TrackedWire: Identifiable, Codable, Equatable {
    let id: UUID                     // STABLE across frames
    let contour: WireContour         // Current frame detection
    let velocity: CGVector           // Normalized coords/sec
    let ageFrames: Int               // Frames since first seen
    let trackingConfidence: Float    // 0.0-1.0
}
```

### 2. `Models/CircuitCamera/WireTrackingConfig.swift` (~30 lines)
**Purpose:** Tracking parameters
**Contains:** `WireTrackingConfig` struct matching SHARED-MODELS.md

```swift
struct WireTrackingConfig: Codable, Equatable {
    var iouThreshold: Float          // 0.3 default
    var maxMissingFrames: Int        // 15 frames = 1 sec at 15 FPS
    var velocitySmoothingFactor: Float // 0.7 EMA alpha
    var minTrackingConfidence: Float   // 0.5

    static func defaults() -> WireTrackingConfig
}
```

### 3. `Services/CircuitCamera/WireTrackingEngine.swift` (~15 lines)
**Purpose:** Protocol for pluggable tracking implementations
**Contains:** `WireTrackingEngine` protocol matching SHARED-MODELS.md

```swift
protocol WireTrackingEngine {
    func updateTracking(with contours: [WireContour]) async -> [TrackedWire]
}
```

### 4. `Services/CircuitCamera/WireTracker.swift` (~200 lines)
**Purpose:** IOU-based wire tracking implementation
**Contains:** `WireTracker` class conforming to `WireTrackingEngine`
**Dependencies:** Foundation, CoreGraphics

**Internal state:**
```swift
private struct TrackState {
    let id: UUID              // Stable tracking ID
    var lastContour: WireContour
    var lastBBox: CGRect      // Cached bounding box
    var lastCenter: CGPoint   // Cached centroid
    var velocity: CGVector
    var ageFrames: Int
    var missedFrames: Int
}

private var activeTracks: [UUID: TrackState] = [:]
```

### 5. Integration update: `Views/CircuitCamera/CircuitCameraView.swift`
**Modify** `CircuitCameraManager` to pipe Agent 1 output through Agent 2:
```swift
private let tracker = WireTracker()  // Add
// In frame callback:
let contours = try await detector.detectWires(...)
let tracked = await tracker.updateTracking(with: contours)  // Add
self.wireCount = tracked.count  // Change from contours.count
```

---

## Implementation Order

```
TrackedWire.swift          (no dependencies)
WireTrackingConfig.swift   (no dependencies)
WireTrackingEngine.swift   (needs TrackedWire, WireContour)
WireTracker.swift          (needs all above)
CircuitCameraView.swift    (integration — modify existing)
```

---

## Key Algorithms

### 4.1 Bounding Box from WireContour

Compute axis-aligned bounding box from contour path points:
```swift
func boundingBox(for contour: WireContour) -> CGRect {
    let xs = contour.path.map(\.x)
    let ys = contour.path.map(\.y)
    let minX = xs.min()!, maxX = xs.max()!
    let minY = ys.min()!, maxY = ys.max()!
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}
```

### 4.2 IOU Calculation

```swift
func iou(_ a: CGRect, _ b: CGRect) -> Float {
    let intersection = a.intersection(b)
    if intersection.isNull { return 0.0 }
    let intersectionArea = intersection.width * intersection.height
    let unionArea = a.width * a.height + b.width * b.height - intersectionArea
    guard unionArea > 0 else { return 0.0 }
    return Float(intersectionArea / unionArea)
}
```

### 4.3 Hungarian-style Greedy Matching

For each frame:
1. Compute IOU matrix: `activeTracks × newContours`
2. Greedy match: pick highest IOU pair, mark both as matched, repeat
3. Matched pairs (IOU > threshold): update existing track with new contour
4. Unmatched new contours: create new track
5. Unmatched old tracks: increment `missedFrames`; remove if `missedFrames > maxMissingFrames`

**Why greedy, not full Hungarian?** With <20 wires typical, greedy is fast (<1ms) and sufficient. Full Hungarian is O(n³) — overkill for this scale.

### 4.4 Velocity Estimation (EMA)

Exponential moving average smooths jitter:
```swift
let rawVelocity = CGVector(
    dx: (newCenter.x - oldCenter.x) / timeDelta,
    dy: (newCenter.y - oldCenter.y) / timeDelta
)
let alpha = config.velocitySmoothingFactor  // 0.7
velocity = CGVector(
    dx: alpha * rawVelocity.dx + (1 - alpha) * oldVelocity.dx,
    dy: alpha * rawVelocity.dy + (1 - alpha) * oldVelocity.dy
)
```

### 4.5 Tracking Confidence

Confidence based on match quality and track age:
```swift
let matchScore = iouValue / 1.0          // Normalized IOU (already 0-1)
let ageBonus = min(Float(ageFrames) / 30.0, 0.2)  // Up to +0.2 for established tracks
let confidence = min(1.0, matchScore * 0.8 + ageBonus)
```

New tracks start at confidence = detection confidence × 0.5 (unproven).

---

## Concurrency Design

- `WireTracker`: regular class (implicitly `@MainActor` from project setting) — tracking is fast (<1ms) so main actor is acceptable
- `updateTracking(with:)` is `async` per protocol but doesn't need background dispatch
- Alternatively: could be `nonisolated` if perf becomes an issue, but unlikely at <20 wires

---

## Acceptance Criteria

### Functional
- [ ] `WireTracker` conforms to `WireTrackingEngine` protocol
- [ ] Stable IDs maintained across 30+ consecutive frames for stationary wires
- [ ] New wires appearing mid-stream get fresh UUIDs
- [ ] Wires missing for >15 frames (1 sec) are removed from active tracks
- [ ] Returns empty array when no contours (no crash)

### Performance
- [ ] <5ms per `updateTracking()` call with 20 wires
- [ ] No memory growth over time (tracks cleaned up)
- [ ] Handles 0 to 50 contours per frame

### Tracking Quality
- [ ] <10% ID flicker rate on stationary wires
- [ ] Velocity estimates smooth (no frame-to-frame jitter)
- [ ] Works when wires partially occluded (partial bbox overlap still matches)

### Integration
- [ ] `CircuitCameraManager` pipes detection → tracking → UI
- [ ] Wire count in UI reflects tracked (stable) count, not raw detection count

---

## Open Questions (Resolved)

| Question | Decision |
|----------|----------|
| Velocity: EMA or simple delta? | **EMA** with alpha=0.7 (smoother, handles frame drops) |
| Two wires crossing (both >0.3 IOU)? | **Greedy best-match** — highest IOU wins, second wire gets next best or new ID |
| Wire splits (one → two)? | Not handled in v1 — each contour matches independently |
| `@MainActor` or `nonisolated`? | **@MainActor** (implicit) — tracking is fast enough, simplifies state access |

---

## Testing Note

No test target exists in Xcode project. Validation via:
1. Build verification (`xcodebuild`)
2. Visual confirmation — wire count in Camera tab should be stable (not flickering)
3. Unit tests deferred to test target creation task

---

## Handoff to Builder

Builder should implement 5 items in order listed above.
Each file committed individually.
Integration change (CircuitCameraView.swift) committed last.
