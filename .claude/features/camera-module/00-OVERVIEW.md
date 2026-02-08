Here are the complete `.md` files as standalone text blocks you can copy:

***

## **File 1:** `.claude/features/camera-module/00-OVERVIEW.md`

```markdown
# Circuit Camera Module - Architecture Overview

**Status:** In Progress (Agent 1 active)
**Last Updated:** February 8, 2026
**Owner:** FlowDoc Engineering

---

## Purpose

The Circuit Camera module enables real-time detection and documentation of electronic circuits and connections. Users point their iPhone camera at breadboards, dev boards, and electronics setups to automatically detect wires, map connections, and generate documentation.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Camera Pipeline                           │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Agent 1: Wire Detection (VNDetectContoursRequest)          │
│  Output: [WireContour]                                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Agent 2: Wire Tracking (IOU matching, stable IDs)          │
│  Output: [TrackedWire]                                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Agent 3: Coordinate Mapping (breadboard grid fitting)      │
│  Output: [MappedConnection]                                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Agent 4: Overlay Rendering (CALayer overlays)              │
│  Output: Visual feedback on camera view                      │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Agent 5: Snapshot Persistence (save to session)            │
│  Output: CircuitSnapshot in database                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Agent Responsibilities

### Agent 1: Wire Detection (ACTIVE)
**Status:** ✅ Spec complete, implementation in progress
**File:** `01-wire-detection.md`
**Responsibility:** Detect wire contours in camera frames using Vision framework
**Input:** `CVPixelBuffer` from camera
**Output:** `[WireContour]` with normalized coordinates
**Dependencies:** None

### Agent 2: Wire Tracking (PLANNED)
**Status:** ⏳ Waiting for Agent 1 completion
**File:** `02-wire-tracking.md` (not created yet)
**Responsibility:** Track wires across frames, assign stable IDs
**Input:** `[WireContour]` from Agent 1
**Output:** `[TrackedWire]` with stable IDs and velocity
**Dependencies:** Agent 1's `WireContour` model

### Agent 3: Coordinate Mapping (PLANNED)
**Status:** ⏳ Waiting for Agent 2 completion
**File:** `03-coordinate-mapping.md` (not created yet)
**Responsibility:** Map wire endpoints to breadboard holes / dev board pins
**Input:** `[TrackedWire]` from Agent 2
**Output:** `[MappedConnection]` with logical labels
**Dependencies:** Agent 2's `TrackedWire` model

### Agent 4: Overlay Rendering (PLANNED)
**Status:** ⏳ Can start in parallel with Agent 3
**File:** `04-overlay-rendering.md` (not created yet)
**Responsibility:** Render visual overlays on camera view
**Input:** `[TrackedWire]` from Agent 2, `[MappedConnection]` from Agent 3
**Output:** CALayer overlays with colored wires and labels
**Dependencies:** Agents 2 & 3 models

### Agent 5: Snapshot Persistence (PLANNED)
**Status:** ⏳ Waiting for all agents complete
**File:** `05-snapshot-persistence.md` (not created yet)
**Responsibility:** Capture and save circuit snapshots to session
**Input:** All detection data + current camera frame
**Output:** `CircuitSnapshot` saved to DatabaseManager
**Dependencies:** All other agents' models

---

## Shared Data Models

**All agents MUST use these exact types** (defined in `.claude/SHARED-MODELS.md`):

### Core Types

```swift
// Agent 1 output
struct WireContour: Identifiable, Codable, Equatable {
    let id: UUID
    let path: [CGPoint]      // Vision normalized coords (bottom-left origin)
    let confidence: Float    // 0.0-1.0
    let colorHint: RGB?      // Optional in v1
    let timestamp: Date
    let metadata: ContourMetadata
}

// Agent 2 output
struct TrackedWire: Identifiable, Codable, Equatable {
    let id: UUID             // Stable across frames
    let contour: WireContour
    let velocity: CGVector   // Estimated motion
    let ageFrames: Int       // Frames since first detection
}

// Agent 3 output
struct MappedConnection: Identifiable, Codable, Equatable {
    let id: UUID
    let wireID: UUID
    let startNode: Node
    let endNode: Node
    let confidence: Float
}

struct Node: Codable, Equatable {
    let type: NodeType       // .breadboardHole, .devPin, .modulePin
    let label: String        // "Row 12F", "GPIO23", etc.
    let position: CGPoint    // Vision normalized coords
}

// Agent 5 output
struct CircuitSnapshot: Identifiable, Codable {
    let id: UUID
    let sessionID: UUID
    let timestamp: Date
    let frameImage: Data     // JPEG compressed
    let wires: [TrackedWire]
    let connections: [MappedConnection]
    let metadata: SnapshotMetadata
}
```

---

## Coordinate System Standard

**ALL agents must use Vision framework normalized coordinates:**
- Origin: **Bottom-left** (0, 0)
- X-axis: Left → Right (0 → 1)
- Y-axis: Bottom → Top (0 → 1)
- Device orientation: Portrait-up relative to sensor

**UI coordinate conversion (Agent 4 only):**
```swift
// Vision → UIKit
let uiPoint = CGPoint(
    x: visionPoint.x,
    y: 1.0 - visionPoint.y  // Flip Y-axis
)
```

---

## Performance Requirements

| Metric | Target | Device |
|--------|--------|--------|
| Detection FPS | 15+ | iPhone 11 Pro |
| Detection FPS | 25+ | iPhone 17 Pro |
| Battery drain | <5% per hour | All devices |
| Memory usage | <50MB | All devices |
| Cold start | <500ms | First detection |

---

## Development Phases

### Phase 1: Core Detection (Current)
- ✅ Agent 1: Wire detection
- ⏳ Agent 2: Wire tracking
- ⏳ Agent 4: Basic overlay rendering
- **Goal:** See wire outlines on camera view

### Phase 2: Coordinate Mapping
- ⏳ Agent 3: Breadboard grid detection
- ⏳ Agent 3: Pin mapping for ESP32 DevKit
- **Goal:** Show "Row 12F → GPIO23" labels

### Phase 3: Persistence & Export
- ⏳ Agent 5: Snapshot capture
- ⏳ Integration with existing Session model
- **Goal:** Save circuit snapshots to session, export in HTML

### Phase 4: LLM Integration (Future)
- On-device Qwen 2.5 1.5B for connection inference
- Natural language explanations: "This likely powers the ESP32"
- Confidence reasoning: "High confidence: red wire = 5V"

---

## Testing Strategy

### Integration Testing
Each agent must pass integration tests with upstream dependencies:
- Agent 2 tests: Feed synthetic `WireContour[]` from Agent 1
- Agent 3 tests: Feed synthetic `TrackedWire[]` from Agent 2
- Agent 4 tests: Render Agent 2 & 3 outputs
- Agent 5 tests: Save full pipeline output

### End-to-End Testing
Test dataset: `test-data/circuit-camera/`
- `breadboard-good-light/`: 5 scenes, 50 labeled wires
- `breadboard-low-light/`: 3 scenes, 24 labeled wires
- `esp32-devkit/`: 3 scenes with dev board
- `no-wires/`: 2 scenes (validate no false positives)

### Acceptance Criteria
- [ ] Agent 1: ≥70% wire detection recall
- [ ] Agent 2: <10% ID flicker rate
- [ ] Agent 3: ≥60% correct pin mapping
- [ ] Agent 4: 15+ FPS rendering
- [ ] Agent 5: <500ms snapshot save time

---

## File Structure

```
FlowDoc/
├── .claude/
│   ├── SHARED-MODELS.md                    ← Read first!
│   └── features/
│       └── camera-module/
│           ├── 00-OVERVIEW.md              ← You are here
│           ├── 01-wire-detection.md        ← Agent 1 spec
│           ├── 02-wire-tracking.md         ← (future)
│           ├── 03-coordinate-mapping.md    ← (future)
│           ├── 04-overlay-rendering.md     ← (future)
│           └── 05-snapshot-persistence.md  ← (future)
│
├── Services/
│   ├── CircuitCamera/
│   │   ├── WireDetector.swift              ← Agent 1 creates
│   │   ├── WireTracker.swift               ← Agent 2 creates
│   │   ├── CoordinateMapper.swift          ← Agent 3 creates
│   │   └── CircuitSnapshotManager.swift    ← Agent 5 creates
│   └── DatabaseManager.swift               ← Agent 5 modifies
│
├── Models/
│   └── CircuitCamera/
│       ├── WireContour.swift               ← Agent 1 creates
│       ├── TrackedWire.swift               ← Agent 2 creates
│       ├── MappedConnection.swift          ← Agent 3 creates
│       └── CircuitSnapshot.swift           ← Agent 5 creates
│
└── Views/
    └── CircuitCamera/
        ├── CircuitCameraView.swift         ← Agent 4 creates
        └── CircuitOverlayView.swift        ← Agent 4 creates
```

---

## Open Questions

### Before Agent 2 Starts:
- [ ] IOU threshold for wire matching across frames? (Recommend: 0.3)
- [ ] Maximum age for lost wire before ID expires? (Recommend: 15 frames = 1 second)

### Before Agent 3 Starts:
- [ ] Which dev boards to support in v1? (Recommend: ESP32 DevKit only)
- [ ] Breadboard type detection needed or user-selects? (Recommend: auto-detect)

### Before Agent 4 Starts:
- [ ] Overlay style: confidence-based opacity or fixed? (Recommend: opacity = confidence)
- [ ] Label positioning: avoid overlaps or simple center-placement? (Recommend: simple first)

### Before Agent 5 Starts:
- [ ] JPEG compression quality for snapshot images? (Recommend: 0.8)
- [ ] Maximum snapshots per session before warning? (Recommend: 50)

---

## Success Metrics (Phase 1)

- [ ] Agent 1 detects wires at 15 FPS on test device
- [ ] Agent 1 achieves ≥70% recall on test dataset
- [ ] User can see wire outlines on camera view in real-time
- [ ] No crashes during 10-minute continuous recording
- [ ] Battery drain <5% during 10-minute test session

---

**Next Step:** Complete Agent 1 implementation (`01-wire-detection.md`)
```

***
