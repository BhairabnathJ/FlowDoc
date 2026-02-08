# Wire Detection Implementation Plan

**Date:** 2026-02-08
**Spec:** `.claude/features/camera-module/01-wire-detection.md`
**Branch:** `feature/wire-detection`

---

## Context

FlowDoc's Phase 3 Circuit Camera feature needs real-time wire detection on breadboard images. This is Agent 1 — the first component in the pipeline. It takes `CVPixelBuffer` frames and outputs `[WireContour]` using Apple's Vision framework contour detection. No CircuitCamera code exists yet.

---

## Files to Create (in order)

All paths relative to `/Users/theri/Documents/trials/FlowDoc/FlowDoc/FlowDoc/`

### 1. `Models/CircuitCamera/WireContour.swift` (~50 lines)
- `WireContour` struct (Identifiable, Codable, Equatable) — matches SHARED-MODELS.md exactly
- `RGB` struct (Codable, Equatable)
- `ContourMetadata` struct (Codable, Equatable)
- Imports: Foundation, CoreGraphics

### 2. `Models/CircuitCamera/CircuitCameraError.swift` (~30 lines)
- `CircuitCameraError` enum conforming to `Error, LocalizedError`
- 6 cases from SHARED-MODELS.md: `visionProcessingFailed(String)`, `invalidPixelBuffer`, `unsupportedPixelFormat`, `trackingFailed(String)`, `mappingFailed(String)`, `snapshotCaptureFailed(String)`
- Imports: Foundation

### 3. `Models/CircuitCamera/WireDetectionConfig.swift` (~70 lines)
- Must match SHARED-MODELS.md exactly — all 14 fields including `maximumImageDimension`, `contrastAdjustment`, `detectsDarkOnLight`, `minPixelLength`, `minAspectRatio`, `maxThicknessRatio`, `minPointCount`, `rdpEpsilonRatio`, `enableColorSampling`, weight fields, `targetFPS`, `maxProcessingTimeMs`
- `static func deviceDefault()` — uses UIDevice.modelIdentifier for device-tier detection (iPhone17→768, iPhone15/16→640, else→512)
- `UIDevice.modelIdentifier` extension (utsname + withMemoryRebound pattern from spec)
- Imports: Foundation, UIKit

### 4. `Services/CircuitCamera/WireDetectionEngine.swift` (~15 lines)
- Protocol with single method: `func detectWires(in:orientation:timestamp:) async throws -> [WireContour]`
- Imports: Foundation, CoreGraphics, AVFoundation

### 5. `Services/CircuitCamera/FrameThrottle.swift` (~25 lines)
- `actor FrameThrottle` — own isolation domain (not MainActor)
- `init(targetFPS: Double)`, `func shouldProcess(timestamp: Date) -> Bool`
- Time-based: tracks `lastProcessTime`, compares against `minInterval = 1.0/targetFPS`

### 6. `Services/CircuitCamera/VisionFrameworkDetector.swift` (~250 lines)
- `nonisolated final class VisionFrameworkDetector: WireDetectionEngine` — opts out of MainActor
- Takes `WireDetectionConfig` in init
- **Detection pipeline:**
  1. Validate pixel format (BGRA supported, throw on unsupported)
  2. `VNDetectContoursRequest` with revision 2, config-driven settings
  3. `VNImageRequestHandler` from CVPixelBuffer
  4. Extract points from `VNContour.normalizedPath` via `CGPath.applyWithBlock` (moveToPoint, addLineToPoint, addQuadCurveToPoint, addCurveToPoint)
  5. Filter: points ≥ `minPointCount`, pixel length ≥ `minPixelLength`, aspect ≥ `minAspectRatio`, thickness ≤ max
  6. RDP simplification with epsilon = `rdpEpsilonRatio * maximumImageDimension`
  7. Confidence scoring: length×0.40 + aspect×0.40 + straightness×0.20
  8. Return ALL detections (no confidence filtering — spec requirement)
- **Private helpers:** `extractPoints(from:)`, `shouldKeepContour(_:config:)`, `simplifyRDP(_:epsilon:)`, `perpendicularDistance(_:lineStart:lineEnd:)`, `computeConfidence(...)`, `computeStraightness(_:)`

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| MainActor opt-out | `nonisolated` on VisionFrameworkDetector | Vision processing must NOT block main thread |
| FrameThrottle isolation | `actor` | Thread-safe without MainActor; own isolation |
| Contour extraction | `normalizedPath.applyWithBlock` | CGPath → [CGPoint]; handles all path element types |
| `detectsDarkOnLight` | `false` | Spec: wires on white breadboard |
| Confidence filtering | None at Agent 1 | Spec: return ALL detections for downstream filtering |
| Color sampling | Disabled (`colorHint = nil`) | Spec: skip in v1 |
| Coordinate system | Vision normalized (bottom-left origin) | SHARED-MODELS.md requirement |

---

## Concurrency Notes

- Project has `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` — all types implicitly @MainActor
- `VisionFrameworkDetector`: marked `nonisolated final class` to run Vision off main thread
- `FrameThrottle`: `actor` keyword gives it own isolation domain
- `WireDetectionEngine` protocol: `async throws` methods allow callers to await from any context
- Model structs (WireContour, etc.): value types, implicitly Sendable — safe to pass across isolation boundaries

---

## Files NOT Modified
- `CameraController.swift` — Agent 4's responsibility
- `DatabaseManager.swift` — Agent 5's responsibility
- No UI files — Agent 4's responsibility
- `project.pbxproj` — PBXFileSystemSynchronizedRootGroup auto-includes new files

---

## Testing Note
No test target exists in the Xcode project. Tests are deferred — validation will happen via:
1. Build verification (`xcodebuild` compile check)
2. Integration testing when Agent 2 (tracking) connects to camera pipeline
3. Test target + unit tests as a separate follow-up task

---

## Verification

1. **Build check:** `xcodebuild -scheme FlowDoc -destination 'platform=iOS Simulator,id=95638297-6C07-4134-855A-ACA7771CEC50' -configuration Debug build`
2. Confirm all 6 files compile with no errors/warnings
3. Confirm `VisionFrameworkDetector` conforms to `WireDetectionEngine` protocol
4. Confirm model structs match SHARED-MODELS.md definitions exactly
