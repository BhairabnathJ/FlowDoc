# FlowDoc Feature Inventory

> Auto-generated from codebase analysis on 2026-02-07
> Source: `/Users/theri/Documents/trials/FlowDoc/FlowDoc/FlowDoc/`

---

## Feature Summary

| # | Feature | Spec Ref | Status | Completion | Phase |
|---|---------|----------|--------|------------|-------|
| 1 | Always-On Audio Recording | FR-1 | Complete | 85% | 1 |
| 2 | On-Device Transcription | FR-2 | In Progress | 55% | 1 |
| 3 | Privacy Kill Switch | FR-3 | In Progress | 40% | 1 |
| 4 | Photo/Video Capture | FR-4 | Complete | 70% | 1 |
| 5 | Session Storage & Retrieval | FR-5 | Complete | 75% | 1 |
| 6 | HTML Export | FR-6 | Complete | 65% | 1 |
| 7 | Design System | — | Complete | 95% | 1 |
| 8 | App Navigation & Structure | — | Complete | 80% | 1 |
| 9 | Database Reactivity | — | Not Started | 0% | 1 |
| 10 | AI Summaries & Key Points | FR-7 | Not Started | 0% | 2 |
| 11 | Proactive AI Nudges | FR-8 | Not Started | 0% | 2 |
| 12 | Circuit Camera (Vision AI) | FR-9 | Not Started | 0% | 3 |
| 13 | Circuit Camera (CoreML YOLO) | FR-9 | Not Started | 0% | 3 |
| 14 | On-Device LLM (DeepSeek) | — | Not Started | 0% | 3 |

**Overall Phase 1 MVP: ~65%**

---

## Detailed Feature Breakdown

---

### 1. Always-On Audio Recording (FR-1)

**Status:** Complete | **Completion:** 85%

Records audio using AVAudioRecorder with background task support, interruption handling, and pause/resume.

#### What's implemented:
- [x] AVAudioRecorder with M4A format, 16kHz, mono
- [x] Start / pause / resume / stop recording lifecycle
- [x] Duration timer with formatted elapsed time
- [x] Background task support (`UIBackgroundTaskIdentifier`)
- [x] AVAudioSession interruption handling (auto-pause on phone call)
- [x] Session state persistence on app background (scenePhase observer)
- [x] 30-second chunk processing timer (for transcription pipeline)
- [x] Audio session config: `.playAndRecord`, `.defaultToSpeaker`, `.allowBluetoothHFP`

#### What's missing:
- [ ] Voice Activity Detection (VAD) to skip silence
- [ ] Adaptive sample rate reduction during silence
- [ ] Auto-stop after configurable timeout (spec: default 4 hours)
- [ ] Rolling buffer cleanup after transcription
- [ ] Background audio mode not fully tested for extended sessions
- [ ] Persistent system notification during recording

#### File locations:
| File | Purpose |
|------|---------|
| `Services/AudioRecorder.swift` | Core recording service (307 lines) |
| `FlowDocApp.swift` | scenePhase observer for background state |

#### Dependencies:
- AVFoundation, UIKit
- `TranscriptionEngine` (receives audio chunks)
- `KillSwitchDetector` (emergency stop)
- `DatabaseManager` (session persistence)

---

### 2. On-Device Transcription (FR-2)

**Status:** In Progress | **Completion:** 55%

Uses Apple Speech framework (SFSpeechRecognizer) for live on-device transcription. Falls back to stub mode if denied.

#### What's implemented:
- [x] SFSpeechRecognizer with on-device recognition (`requiresOnDeviceRecognition = true`)
- [x] Live audio tap via AVAudioEngine (1024 buffer, input node)
- [x] Partial results with real-time `liveText` updates
- [x] Segment creation at sentence boundaries (`.`, `!`, `?`)
- [x] Segment creation at word count threshold (6+ words)
- [x] Auto-restart after Apple's ~60s per-request limit
- [x] Stub fallback mode with sample phrases (when speech auth denied)
- [x] Synchronous auth check to avoid race condition
- [x] Segments saved to DatabaseManager on stop
- [x] Pause/resume support

#### What's missing:
- [ ] WhisperKit integration (spec calls for whisper.cpp via WhisperKit SPM)
- [ ] Speaker diarization (multiple speakers)
- [ ] Confidence scores per segment (always 1.0 currently)
- [ ] Custom vocabulary injection for technical terms
- [ ] Model download progress UI (for WhisperKit)
- [ ] Accuracy ~50% with Speech framework vs spec target >90% WER
- [ ] Live transcript display in RecordingView (segments not wired to UI)

#### File locations:
| File | Purpose |
|------|---------|
| `Services/TranscriptionEngine.swift` | Speech framework + stub fallback (325 lines) |
| `Models/Segment.swift` | Transcript segment model |
| `Models/Transcript.swift` | Transcript container model |

#### Dependencies:
- Speech framework, AVFoundation, Combine
- `DatabaseManager` (segment persistence)
- `AudioRecorder` (start/stop lifecycle)
- Requires `NSSpeechRecognitionUsageDescription` in Info.plist (set via pbxproj)

---

### 3. Privacy Kill Switch (FR-3)

**Status:** In Progress | **Completion:** 40%

Detects volume-down x3 hardware gesture to emergency-stop recording. Other triggers not yet implemented.

#### What's implemented:
- [x] Volume-down x3 detection via KVO on `outputVolume`
- [x] 1.5-second press window with auto-reset timer
- [x] `onTrigger` callback wired to `AudioRecorder.stopRecording()`
- [x] Start/stop lifecycle tied to recording session
- [x] In-app pause button on RecordingView
- [x] Privacy Pause menu item in RecordingView toolbar

#### What's missing:
- [ ] Voice phrase detection ("BIG APPLE BAZINGA" or custom)
- [ ] Customizable trigger phrase (user settings)
- [ ] Auto-pause on phone call detection (interruption handler pauses, doesn't kill)
- [ ] Transcript gap indicator `[Recording paused: 5:23 - 5:45]`
- [ ] Visual state change to yellow pause icon
- [ ] Privacy timeout (auto-stop after X hours)
- [ ] Settings UI for kill switch preferences
- [ ] Enable/disable hardware button trigger setting

#### File locations:
| File | Purpose |
|------|---------|
| `Services/KillSwitchDetector.swift` | Volume gesture detection (69 lines) |
| `Services/AudioRecorder.swift` | Wires kill switch to stopRecording |
| `Views/Recording/RecordingView.swift` | Pause button + Privacy Pause menu |

#### Dependencies:
- AVFoundation (AVAudioSession volume KVO)
- `AudioRecorder` (trigger target)
- Future: WhisperKit or SFSpeechRecognizer for voice phrase detection

---

### 4. Photo/Video Capture (FR-4)

**Status:** Complete | **Completion:** 70%

In-session camera capture with photos linked to transcript timeline. Full AVCaptureSession lifecycle.

#### What's implemented:
- [x] AVCaptureSession with `.photo` preset, back camera
- [x] Photo capture via AVCapturePhotoOutput + delegate
- [x] JPEG compression (0.85 quality) and file save
- [x] Photos saved to `Documents/Media/{sessionID}/{uuid}.jpg`
- [x] MediaCapture model with transcript offset linking
- [x] Camera permission request flow
- [x] CameraView with live preview (UIViewRepresentable)
- [x] Shutter button with white flash feedback
- [x] "Saved" toast with timestamp
- [x] Sheet presentation from RecordingView
- [x] Camera session startup on background thread (.userInteractive QoS)
- [x] MediaGridView showing captured photos in SessionDetailView
- [x] Fullscreen image viewer with double-tap zoom
- [x] `resolvedFileURL` for stale container UUID handling

#### What's missing:
- [ ] Video capture (spec: up to 30s, H.264, 1080p)
- [ ] Burst mode (spec: 3 rapid photos)
- [ ] Thumbnail generation (spec mentions it)
- [ ] Photo captions/annotations UI
- [ ] Pinch-to-zoom in fullscreen viewer (removed due to iOS 26 API change)

#### File locations:
| File | Purpose |
|------|---------|
| `Services/CameraController.swift` | AVCaptureSession + photo processing (185 lines) |
| `Views/Recording/CameraView.swift` | Camera preview + capture UI (148 lines) |
| `Views/Detail/MediaGridView.swift` | Photo grid + fullscreen viewer (153 lines) |
| `Models/MediaCapture.swift` | Media model with resolvedFileURL (50 lines) |

#### Dependencies:
- AVFoundation, UIKit
- `DatabaseManager` (media capture persistence)
- `AudioRecorder` (provides transcript offset)
- `Session` model (session ID linkage)

---

### 5. Session Storage & Retrieval (FR-5)

**Status:** Complete | **Completion:** 75%

JSON-backed persistence for sessions, segments, and media captures. Singleton DatabaseManager.

#### What's implemented:
- [x] JSON file persistence (`flowdoc_sessions.json`, `flowdoc_segments.json`)
- [x] Session CRUD: save, update, fetchAll (sorted by date)
- [x] Segment CRUD: save, fetch by transcript ID
- [x] MediaCapture CRUD: save, fetch by session ID
- [x] Media stored per-session: `Documents/Media/{sessionID}/captures.json`
- [x] Load from disk on init
- [x] ObservableObject conformance on DatabaseManager

#### What's missing:
- [ ] **@Published properties** — views don't reactively update (must close/reopen app)
- [ ] SQLite migration (spec calls for SQLite.swift, currently JSON)
- [ ] Cascade delete (session deletion doesn't clean up media/segments)
- [ ] Session archiving functionality
- [ ] Data retention policies (7d/30d/forever)
- [ ] Audio file cleanup post-transcription
- [ ] Search/filter sessions

#### File locations:
| File | Purpose |
|------|---------|
| `Services/DatabaseManager.swift` | JSON persistence singleton (129 lines) |
| `Models/Session.swift` | Session model (49 lines) |
| `Models/Segment.swift` | Transcript segment model (39 lines) |
| `Models/Transcript.swift` | Transcript container (17 lines) |
| `Models/MediaCapture.swift` | Media capture model (50 lines) |

#### Dependencies:
- Foundation (JSONEncoder/Decoder, FileManager)
- Combine (ObservableObject)

---

### 6. HTML Export (FR-6)

**Status:** Complete | **Completion:** 65%

Generates self-contained HTML with dark mode support, compatible with Notion/Obsidian.

#### What's implemented:
- [x] HTML generation with session metadata (date, duration)
- [x] Transcript rendering with timestamps and speaker labels
- [x] Styled CSS with responsive layout (max-width 780px)
- [x] Dark mode support via `@media(prefers-color-scheme:dark)`
- [x] XSS-safe HTML escaping
- [x] Copy to clipboard (`UIPasteboard.general`)
- [x] Share via `ShareLink` (iOS share sheet)
- [x] Haptic feedback on copy
- [x] Export bar in SessionDetailView

#### What's missing:
- [ ] Media grid in HTML (photos not included in export)
- [ ] Base64 image embedding (spec: <5 images inline, 5+ zip)
- [ ] Key points section (Phase 2 placeholder exists)
- [ ] Action items section (Phase 2 placeholder exists)
- [ ] Participants list in export
- [ ] Location in export
- [ ] Save as .html file option
- [ ] Pause gap indicators in transcript

#### File locations:
| File | Purpose |
|------|---------|
| `Services/HTMLExporter.swift` | HTML generation singleton (70 lines) |
| `Views/Detail/SessionDetailView.swift` | Export bar UI (174 lines) |

#### Dependencies:
- Foundation, UIKit (UIPasteboard)
- `Session`, `Segment` models
- `DatabaseManager` (data loading)

---

### 7. Design System

**Status:** Complete | **Completion:** 95%

Full design token system with colors, typography, spacing, and reusable components.

#### What's implemented:
- [x] **Colors:** Light/dark mode adaptive — backgroundPrimary/Secondary/Tertiary, textPrimary/Secondary/Tertiary, accentPrimary, stateRecording, statePaused, stateWarning
- [x] **Typography:** display (30pt), title1 (24pt), title2 (20pt), headline, body (16pt), bodyMedium, small (14pt), caption (12pt), tiny (11pt)
- [x] **Spacing:** xs(4), sm(8), md(12), lg(16), xl(24), xxl(32)
- [x] **Corner Radius:** sm(6), md(10), lg(12)
- [x] **Color(hex:)** extension for hex color initialization
- [x] **PrimaryButton:** 48pt height, full width, accent bg
- [x] **RecordingDot:** 12x12 pulsing red circle (1s animation)
- [x] **StatusBadge:** Pill badge with recording/paused/processing/completed states
- [x] **TagView:** Accent-colored pill labels

#### What's missing:
- [ ] SecondaryButton component (spec defines it, not implemented)
- [ ] Dynamic Type support (uses fixed font sizes, not `.body` etc.)

#### File locations:
| File | Purpose |
|------|---------|
| `Design/DesignTokens.swift` | Colors, Typography, Spacing, CornerRadius |
| `Design/ColorExtensions.swift` | Color(hex:) initializer |
| `Views/Components/PrimaryButton.swift` | Full-width CTA button |
| `Views/Components/RecordingDot.swift` | Pulsing recording indicator |
| `Views/Components/StatusBadge.swift` | Session state pill badge |
| `Views/Components/TagView.swift` | Tag/label pill |

#### Dependencies:
- SwiftUI only

---

### 8. App Navigation & Structure

**Status:** Complete | **Completion:** 80%

NavigationStack with typed routes, session list, recording view, and session detail.

#### What's implemented:
- [x] `FlowDocRoute` enum: `.recording`, `.sessionDetail(UUID)`
- [x] NavigationStack with `navigationDestination(for:)` routing
- [x] **HomeView:** Session list with grid layout, active session card, FAB new session button
- [x] **RecordingView:** Timer display, live transcript area, controls bar (pause/stop/camera)
- [x] **SessionDetailView:** Header, summary placeholder, media grid, transcript, export bar
- [x] **SessionCard:** Date, duration, tags in grid card
- [x] Auto-navigate to RecordingView when recording starts
- [x] Auto-dismiss RecordingView when recording stops
- [x] Camera sheet presentation from RecordingView
- [x] Fullscreen media viewer via `.fullScreenCover`

#### What's missing:
- [ ] **TabView** for Circuit Camera tab (planned, not implemented)
- [ ] Settings screen
- [ ] Session search/filter
- [ ] Session deletion (swipe to delete)
- [ ] Pull-to-refresh
- [ ] Onboarding flow

#### File locations:
| File | Purpose |
|------|---------|
| `FlowDocApp.swift` | App entry, StateObject AudioRecorder, scenePhase |
| `Views/Home/HomeView.swift` | Session list + navigation (187 lines) |
| `Views/Home/SessionCard.swift` | Session card component (47 lines) |
| `Views/Recording/RecordingView.swift` | Recording screen (176 lines) |
| `Views/Recording/CameraView.swift` | Camera overlay (148 lines) |
| `Views/Recording/TranscriptRow.swift` | Transcript line (30 lines) |
| `Views/Detail/SessionDetailView.swift` | Session detail screen (174 lines) |
| `Views/Detail/MediaGridView.swift` | Media grid + fullscreen (153 lines) |

#### Dependencies:
- SwiftUI
- `AudioRecorder` (EnvironmentObject)
- `DatabaseManager`, all models

---

### 9. Database Reactivity

**Status:** Not Started | **Completion:** 0%

Sessions/data should appear instantly in UI after recording stops without closing the app.

#### Problem:
HomeView stores sessions in `@State` loaded once in `onAppear`. When recording stops and user navigates back, `onAppear` doesn't re-fire (NavigationStack reuses the view). DatabaseManager is `ObservableObject` but has zero `@Published` properties.

#### What's needed:
- [ ] Add `@Published private(set) var allSessions: [Session]` to DatabaseManager
- [ ] Update `saveSession()` / `updateSession()` to refresh published property
- [ ] HomeView observes DatabaseManager instead of `@State` array
- [ ] Remove manual `onAppear` fetch pattern
- [ ] SessionDetailView refreshes segments reactively

#### File locations (to modify):
| File | Change needed |
|------|---------------|
| `Services/DatabaseManager.swift` | Add @Published allSessions |
| `Views/Home/HomeView.swift` | @ObservedObject DatabaseManager.shared |

#### Dependencies:
- Combine (@Published)
- All views that display session data

---

### 10. AI Summaries & Key Points (FR-7)

**Status:** Not Started | **Completion:** 0%

On-device LLM generates summaries, key points, and action items from transcripts.

#### What exists:
- SessionDetailView has a "Summary" section with "Phase 2" badge placeholder
- Placeholder text: "AI-generated key points and action items will appear here."

#### What's needed:
- [ ] On-device LLM integration (spec: Qwen2.5-0.6B or Phi-3-mini via llama.cpp)
- [ ] SummaryEngine service
- [ ] Summary model (keyPoints, actionItems, technicalSpecs)
- [ ] ActionItem model (task, assignee, priority)
- [ ] Prompt engineering for structured JSON output
- [ ] Summary UI in SessionDetailView
- [ ] Model download + progress UI
- [ ] Summary generation during/after recording

#### File locations (to create):
- `Services/SummaryEngine.swift`
- `Models/Summary.swift`
- `Models/ActionItem.swift`

#### Dependencies:
- llama.cpp Swift bindings or similar
- `TranscriptionEngine` (provides transcript text)
- `DatabaseManager` (summary persistence)
- Requires iPhone 15 Pro+ for acceptable performance

---

### 11. Proactive AI Nudges (FR-8)

**Status:** Not Started | **Completion:** 0%

Real-time keyword detection during transcription to suggest contextual actions.

#### What's needed:
- [ ] NudgeEngine service with keyword matching
- [ ] Nudge model (type, message, timestamp, confidence)
- [ ] NudgeType enum (captureVisual, decisionMade, actionItem, technicalSpec)
- [ ] Keyword dictionaries per nudge type
- [ ] Non-intrusive bottom banner UI
- [ ] Haptic feedback on nudge
- [ ] Swipe to act/dismiss
- [ ] Auto-dismiss after 10 seconds
- [ ] User settings (enable/disable, sensitivity)

#### File locations (to create):
- `Services/NudgeEngine.swift`
- `Models/Nudge.swift`
- `Views/Components/NudgeBanner.swift`

#### Dependencies:
- `TranscriptionEngine` (live transcript segments)
- `CameraController` (capture action)
- `DatabaseManager` (action item logging)

---

### 12. Circuit Camera — Vision Framework (FR-9, Phase 1)

**Status:** Not Started | **Completion:** 0%

Apple Vision framework for real-time contour detection and text recognition on circuit boards.

#### What's needed:
- [ ] CircuitCameraView with live camera preview + overlays
- [ ] CircuitCameraSession (AVCaptureSession + video data output)
- [ ] CircuitVisionService (VNDetectContoursRequest, VNRecognizeTextRequest)
- [ ] CircuitCameraOverlay (contour path rendering, text labels)
- [ ] Frame throttling for performance
- [ ] TabView in FlowDocApp (Sessions + Circuit Camera tabs)

#### File locations (to create):
- `Views/CircuitCamera/CircuitCameraView.swift`
- `Views/CircuitCamera/CircuitCameraOverlay.swift`
- `Services/CircuitVisionService.swift`

#### Dependencies:
- Vision framework, AVFoundation
- `CameraPreviewView` (reuse from CameraView.swift)
- TabView requires FlowDocApp modification

---

### 13. Circuit Camera — CoreML YOLO (FR-9, Phase 2)

**Status:** Not Started | **Completion:** 0%

YOLO11-Nano CoreML model for identifying specific electronic components.

#### What's needed:
- [ ] Export YOLO11-Nano to CoreML on M4 Max
- [ ] Add .mlmodel to Xcode project
- [ ] CircuitDetectionService (VNCoreMLRequest wrapper)
- [ ] DetectedComponent model (label, confidence, boundingBox)
- [ ] Bounding box rendering on camera overlay
- [ ] Combine with Vision contours for full overlay

#### File locations (to create):
- `Services/CircuitDetectionService.swift`
- `Models/DetectedComponent.swift`
- `.mlmodel` file in project

#### Dependencies:
- CoreML, Vision framework
- `CircuitVisionService` (contour overlay base)
- `CircuitCameraView` (camera session)
- Training: Ultralytics + Roboflow (M4 Max)

---

### 14. On-Device LLM — DeepSeek R1 (Phase 3)

**Status:** Not Started | **Completion:** 0%

On-device language model for semantic circuit analysis ("What does this circuit do?").

#### What's needed:
- [ ] DeepSeek R1 1.5B Distill CoreML conversion
- [ ] LLM inference service
- [ ] Circuit analysis prompt engineering
- [ ] UI for asking questions about detected circuits
- [ ] Model download and management

#### Dependencies:
- CoreML or llama.cpp
- `CircuitDetectionService` (component context)
- Requires iPhone 15 Pro+ (8GB RAM)

---

## File Inventory

### Source Files (24 total)

| File | Lines | Feature(s) |
|------|-------|------------|
| **Design/** | | |
| `DesignTokens.swift` | ~120 | Design system tokens |
| `ColorExtensions.swift` | 27 | Color(hex:) extension |
| **Models/** | | |
| `Session.swift` | 49 | Session data model |
| `Segment.swift` | 39 | Transcript segment model |
| `Transcript.swift` | 17 | Transcript container |
| `MediaCapture.swift` | 50 | Photo/video capture model |
| **Services/** | | |
| `AudioRecorder.swift` | 307 | Audio recording + background |
| `TranscriptionEngine.swift` | 325 | Speech recognition + stub |
| `DatabaseManager.swift` | 129 | JSON persistence |
| `CameraController.swift` | 185 | AVCaptureSession photo capture |
| `HTMLExporter.swift` | 70 | HTML generation |
| `KillSwitchDetector.swift` | 69 | Volume gesture detection |
| **Views/Components/** | | |
| `PrimaryButton.swift` | 18 | CTA button component |
| `RecordingDot.swift` | 20 | Pulsing indicator |
| `StatusBadge.swift` | 46 | State pill badge |
| `TagView.swift` | 17 | Tag label component |
| **Views/Home/** | | |
| `HomeView.swift` | 187 | Session list + navigation |
| `SessionCard.swift` | 47 | Session card component |
| **Views/Recording/** | | |
| `RecordingView.swift` | 176 | Recording screen |
| `CameraView.swift` | 148 | Camera overlay + preview |
| `TranscriptRow.swift` | 30 | Transcript line component |
| **Views/Detail/** | | |
| `SessionDetailView.swift` | 174 | Session detail screen |
| `MediaGridView.swift` | 153 | Photo grid + fullscreen |
| **Root** | | |
| `FlowDocApp.swift` | 19 | App entry point |

**Total: ~2,471 lines of Swift**

### Build Configuration

| Setting | Value |
|---------|-------|
| Target | iOS 26.2 |
| Swift | 5.9+ with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| Bundle ID | `UnityProvisions.FlowDoc` |
| Frameworks | AVFoundation, Speech, UIKit, SwiftUI, Combine |
| SPM Packages | WhisperKit (referenced but not linked) |
| Background Modes | `audio` |
| Permissions | Microphone, Camera, Speech Recognition |

---

## Dependency Graph

```
FlowDocApp
├── AudioRecorder (StateObject)
│   ├── TranscriptionEngine.shared
│   │   └── DatabaseManager.shared (saves segments)
│   ├── KillSwitchDetector
│   │   └── AudioRecorder.stopRecording()
│   └── DatabaseManager.shared (saves sessions)
├── HomeView
│   ├── DatabaseManager.shared (fetches sessions — NOT reactive)
│   ├── SessionCard
│   ├── RecordingView
│   │   ├── TranscriptRow
│   │   └── CameraView
│   │       └── CameraController
│   │           └── DatabaseManager.shared (saves media)
│   └── SessionDetailView
│       ├── MediaGridView
│       │   └── MediaFullScreenView
│       ├── TranscriptRow
│       └── HTMLExporter.shared
└── Design System
    ├── DesignTokens (Colors, Typography, Spacing, CornerRadius)
    ├── ColorExtensions
    └── Components (PrimaryButton, RecordingDot, StatusBadge, TagView)
```

---

## Critical Gaps for MVP Completion

1. **Database Reactivity** — Sessions don't refresh after recording (must restart app)
2. **Live Transcript in RecordingView** — TranscriptionEngine segments not wired to RecordingView UI
3. **Transcription Quality** — Speech framework ~50% accuracy vs spec >90% (needs WhisperKit)
4. **Kill Switch Voice Phrase** — Only hardware gesture works; voice detection not implemented
5. **HTML Export Media** — Photos not included in HTML export
6. **Video Capture** — Only photo capture implemented; spec requires video + burst mode
