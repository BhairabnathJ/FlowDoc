# Circuit Camera + Reactive Database Plan

## Context

The user wants two things:

1. **Circuit Camera** - A new tab with an AI-powered camera that can recognize wires, connections, ports, and electronic components on circuit boards. Must use free, open-source, on-device AI (no paid APIs). User has M4 Max MacBook for training.

2. **Reactive Database** - Sessions/data should appear instantly in the UI after recording stops, without needing to close and reopen the app.

### Current State
- App uses NavigationStack (no tabs currently)
- Camera exists for photo capture during recording (CameraController + CameraView)
- No ML/AI frameworks currently integrated (only Speech.framework for transcription)
- DatabaseManager is ObservableObject but has zero @Published properties
- HomeView loads sessions once in `onAppear` and never refreshes

---

## Part 1: Reactive Database Fix

**Problem:** HomeView stores sessions in `@State` loaded once on `onAppear`. When recording stops, `onAppear` doesn't re-fire (view is reused in the stack). DatabaseManager persists data but never notifies views.

**Solution:** Make DatabaseManager publish changes via `@Published`, and have views observe them.

### Files to modify:
- `Services/DatabaseManager.swift` - Add `@Published var allSessions: [Session]`
- `Views/Home/HomeView.swift` - Replace `@State sessions` with `@ObservedObject DatabaseManager.shared`
- `Views/Detail/SessionDetailView.swift` - Refresh data when view appears (already works, but add onChange for live updates)

### Implementation:
1. Add `@Published private(set) var allSessions: [Session] = []` to DatabaseManager
2. Call `objectWillChange.send()` or just update the published property in `saveSession()`, `updateSession()`
3. In HomeView, replace `@State private var sessions` with a computed binding from `DatabaseManager.shared.allSessions`
4. Remove the manual `onAppear { sessions = ... }` fetch pattern
5. Same pattern for segments if needed in SessionDetailView

### Acceptance:
- [ ] Recording stops → HomeView shows new session immediately
- [ ] No app restart needed to see results
- [ ] SessionDetailView shows transcript immediately after navigating

---

## Part 2: Circuit Camera Tab

### Step 1: Add TabView to App

Convert the app from single NavigationStack to a TabView with two tabs:
- **Sessions** (current HomeView flow)
- **Circuit Camera** (new)

**Files to modify:**
- `FlowDocApp.swift` - Wrap content in TabView
- `Views/Home/HomeView.swift` - Becomes content of "Sessions" tab
- New: `Views/CircuitCamera/CircuitCameraView.swift` - Main view for Circuit Camera tab
- New: `Views/CircuitCamera/CircuitCameraOverlay.swift` - AR-style overlay rendering

### Step 2: Vision Framework Integration (Phase 1 - MVP)

Start with Apple's built-in Vision framework for immediate, zero-cost wire/edge detection:

**New files:**
- `Services/CircuitVisionService.swift` - Wraps Vision framework requests

**What it does:**
1. `VNDetectContoursRequest` - Detects wire edges and component outlines in real-time
2. `VNRecognizeTextRequest` - Reads labels on components (resistor values, IC numbers)
3. Contour rendering as colored overlays on the camera preview

**Why Vision first:**
- Built into iOS, zero download, zero cost
- 10ms latency per frame
- Contour detection is excellent for wires and PCB traces
- Text recognition reads component labels
- No model training needed

### Step 3: YOLO Object Detection (Phase 2 - Component Recognition)

Add a CoreML model for identifying specific electronic components:

**Approach:** Use Ultralytics YOLO11-Nano exported to CoreML
- Pre-trained on COCO (80 object classes) as starting point
- Can fine-tune on circuit component dataset later

**New files:**
- `Services/CircuitDetectionService.swift` - CoreML inference wrapper
- `Models/DetectedComponent.swift` - Model for detection results
- Add `.mlmodel` file to Xcode project

**Pipeline:**
1. Camera frame → CoreML inference (YOLO11-Nano) → Bounding boxes + labels
2. Vision Framework contours → Wire/trace overlay
3. Combine both into AR-style overlay on camera preview

**Model options (all free, CoreML-compatible):**
- YOLO11-Nano: 3.2M params, ~60 FPS on Neural Engine, general detection
- Custom fine-tuned: Train on Roboflow with circuit component dataset (200-300 images)
- MobileNetV2: 1.7ms classification for component type identification

### Step 4: DeepSeek R1 1.5B Integration (Phase 3 - Circuit Analysis)

**Optional future phase.** Add on-device LLM for semantic understanding:
- "What does this circuit do?"
- "Identify this component and suggest values"
- DeepSeek R1 1.5B Distill already has CoreML conversion available
- Requires iPhone 15 Pro+ (8GB RAM)

---

## Recommended Build Order

### Sprint 1: Database + Tab Structure (1-2 days)
1. Fix DatabaseManager reactivity (`@Published allSessions`)
2. Update HomeView to observe DatabaseManager
3. Add TabView to FlowDocApp (Sessions + Circuit Camera tabs)
4. Create basic CircuitCameraView with live camera preview

### Sprint 2: Vision Framework Overlays (2-3 days)
1. Create CircuitVisionService with VNDetectContoursRequest
2. Process camera frames through Vision pipeline
3. Render contour overlays on camera preview (colored wire outlines)
4. Add VNRecognizeTextRequest for component label reading
5. Show detected text in an overlay panel

### Sprint 3: CoreML Object Detection (3-5 days)
1. Download/convert YOLO11-Nano to CoreML format on M4 Max
2. Add .mlmodel to Xcode project
3. Create CircuitDetectionService for inference
4. Draw bounding boxes with labels on camera preview
5. Combine with Vision contours for full overlay

### Sprint 4: Polish + Custom Training (ongoing)
1. Collect circuit component images for custom dataset
2. Fine-tune YOLO on Roboflow (free tier)
3. Export custom model to CoreML
4. Replace generic model with circuit-specific model

---

## Architecture

```
CircuitCameraView (SwiftUI)
  └── CameraPreviewView (UIViewRepresentable, reuse existing)
  └── CircuitCameraOverlay (SwiftUI overlay layer)
        ├── Contour paths (from VNDetectContoursRequest)
        ├── Bounding boxes + labels (from CoreML YOLO)
        └── Text annotations (from VNRecognizeTextRequest)

CircuitVisionService
  ├── processFrame(CMSampleBuffer) → [VNContour], [VNRecognizedText]
  └── Uses AVCaptureVideoDataOutput delegate for real-time frames

CircuitDetectionService
  ├── detect(CVPixelBuffer) → [DetectedComponent]
  └── Uses VNCoreMLRequest with YOLO11-Nano .mlmodel
```

---

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| AI Framework (Phase 1) | Apple Vision | Free, built-in, 10ms, no training |
| AI Framework (Phase 2) | YOLO11-Nano CoreML | Free, 60 FPS, exportable from Ultralytics |
| LLM (Phase 3, optional) | DeepSeek R1 1.5B | Free, CoreML conversion exists |
| Tab Structure | SwiftUI TabView | Clean separation, standard iOS pattern |
| Database Reactivity | @Published on DatabaseManager | Minimal change, leverages existing ObservableObject |
| Training Hardware | M4 Max MacBook | Local training via Roboflow/MLX, export CoreML |

---

## Files to Create

| File | Purpose |
|------|---------|
| `Views/CircuitCamera/CircuitCameraView.swift` | Main camera tab view |
| `Views/CircuitCamera/CircuitCameraOverlay.swift` | AR overlay rendering |
| `Services/CircuitVisionService.swift` | Vision framework processing |
| `Services/CircuitDetectionService.swift` | CoreML YOLO inference (Sprint 3) |
| `Models/DetectedComponent.swift` | Detection result model |

## Files to Modify

| File | Change |
|------|--------|
| `FlowDocApp.swift` | Add TabView wrapper |
| `Services/DatabaseManager.swift` | Add @Published allSessions |
| `Views/Home/HomeView.swift` | Observe DatabaseManager instead of @State |

---

## Privacy Guardrails

- All AI processing is ON-DEVICE (Vision framework + CoreML)
- No images sent to external APIs
- No networking whatsoever
- Camera frames processed in memory, not saved unless user captures
- Models bundled with app or downloaded once from Apple CDN

## Verification

1. **Build:** `xcodebuild -scheme FlowDoc -destination 'platform=iOS Simulator,id=95638297-6C07-4134-855A-ACA7771CEC50' -configuration Debug`
2. **Test DB reactivity:** Record session → stop → verify HomeView updates immediately
3. **Test Circuit Camera tab:** Open tab → verify camera preview shows
4. **Test Vision overlays:** Point at wires/objects → verify contour highlighting
5. **Run verifier-flowdoc** after implementation to check for privacy/performance issues
