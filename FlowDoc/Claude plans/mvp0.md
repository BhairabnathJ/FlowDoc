
Plan to implement                                                            │
│                                                                              │
│ FlowDoc Phase 1 MVP - Remaining Work Plan                                    │
│                                                                              │
│ Context                                                                      │
│                                                                              │
│ FlowDoc is an iOS app for hardware teams that provides always-on audio       │
│ recording, on-device transcription, photo capture, and HTML export. The      │
│ project has successfully completed the core infrastructure:                  │
│                                                                              │
│ - ✅ Audio recording with AVFoundation (start/pause/stop)                    │
│ - ✅ SwiftUI UI framework with DesignTokens                                  │
│ - ✅ JSON-based DatabaseManager                                              │
│ - ✅ HTML export with clipboard copy                                         │
│ - ✅ Basic navigation (HomeView, RecordingView, SessionDetailView)           │
│                                                                              │
│ However, several Phase 1 MVP features are incomplete or stubbed. This plan   │
│ identifies the remaining work and proposes a build order to complete the     │
│ MVP.                                                                         │
│                                                                              │
│ Current State Analysis                                                       │
│                                                                              │
│ Completed Features                                                           │
│                                                                              │
│ 1. Audio Recording (FR-1) - AudioRecorder.swift with AVAudioSession          │
│ 2. UI Framework (FR-2) - All main views, components, and DesignTokens        │
│ 3. Session Management (FR-4) - DatabaseManager with CRUD operations          │
│ 4. HTML Export (FR-5) - HTMLExporter with clipboard functionality            │
│                                                                              │
│ Partially Implemented                                                        │
│                                                                              │
│ 1. Photo Capture (FR-1.4) - CameraController and CameraView exist but not    │
│ wired to RecordingView                                                       │
│ 2. Transcription (FR-1.3) - TranscriptionEngine stub exists, needs           │
│ WhisperKit integration                                                       │
│ 3. Kill Switch (FR-3) - KillSwitchDetector stub exists, needs volume button  │
│ implementation                                                               │
│                                                                              │
│ Remaining Features for Phase 1 MVP                                           │
│                                                                              │
│ Priority 1: Camera Photo Capture Integration (QUICK WIN)                     │
│                                                                              │
│ Complexity: Moderate | Dependencies: None                                    │
│                                                                              │
│ Why first: CameraController already exists, just needs UI wiring. Provides   │
│ immediate user value.                                                        │
│                                                                              │
│ Files to modify:                                                             │
│ - Views/Recording/RecordingView.swift - Wire camera button to present        │
│ CameraView sheet                                                             │
│ - Views/Recording/CameraView.swift - Implement capture button action         │
│ - Services/CameraController.swift - Implement takePhoto() method             │
│ - Services/DatabaseManager.swift - Add saveMediaCapture() and                │
│ fetchMediaCaptures() methods                                                 │
│ - Models/Session.swift - Ensure mediaCaptures array is persisted             │
│                                                                              │
│ Implementation steps:                                                        │
│ 1. Update RecordingView camera button to show CameraView sheet               │
│ 2. Pass current session ID to CameraView                                     │
│ 3. Implement photo capture in CameraController (AVCapturePhotoOutput)        │
│ 4. Save JPEG to Documents/Media/[sessionID]/ directory                       │
│ 5. Create MediaCapture object with timestamp and transcript offset           │
│ 6. Add DatabaseManager methods for media persistence                         │
│ 7. Update SessionDetailView to load real media captures                      │
│                                                                              │
│ Acceptance criteria:                                                         │
│ - Camera button in RecordingView opens fullscreen camera                     │
│ - Camera shows live preview with shutter button                              │
│ - Captured photo saves to local storage                                      │
│ - Photo appears in SessionDetailView media grid                              │
│ - MediaCapture persists with correct timestamp and session link              │
│                                                                              │
│ ---                                                                          │
│ Priority 2: Background Recording Support (CRITICAL)                          │
│                                                                              │
│ Complexity: Simple | Dependencies: None                                      │
│                                                                              │
│ Why second: Recording must continue when phone locks or app backgrounds.     │
│ Critical for real-world use.                                                 │
│                                                                              │
│ Files to modify:                                                             │
│ - Services/AudioRecorder.swift - Verify background audio session works       │
│ - FlowDocApp.swift - Add background task handling                            │
│ - FlowDoc.xcodeproj/project.pbxproj - Verify UIBackgroundModes includes      │
│ "audio"                                                                      │
│                                                                              │
│ Implementation steps:                                                        │
│ 1. Verify AVAudioSession category is .playAndRecord with .allowBluetoothHFP  │
│ 2. Add beginBackgroundTask() in AudioRecorder when recording starts          │
│ 3. Add endBackgroundTask() when recording stops                              │
│ 4. Test recording continues with phone locked                                │
│ 5. Test recording continues when app backgrounded                            │
│ 6. Verify status bar shows recording indicator                               │
│                                                                              │
│ Acceptance criteria:                                                         │
│ - Recording continues when phone locks                                       │
│ - Recording continues when app moves to background                           │
│ - Status bar shows audio recording indicator                                 │
│ - Timer updates when returning to foreground                                 │
│ - No data loss on background/foreground transitions                          │
│                                                                              │
│ ---                                                                          │
│ Priority 3: Session Auto-Save on Interruption (ROBUSTNESS)                   │
│                                                                              │
│ Complexity: Simple | Dependencies: None (pairs with Priority 2)              │
│                                                                              │
│ Why third: Prevents data loss from phone calls, app termination, or crashes. │
│                                                                              │
│ Files to modify:                                                             │
│ - Services/AudioRecorder.swift - Add AVAudioSession interruption observers   │
│ - FlowDocApp.swift - Add scenePhase observer for app lifecycle               │
│                                                                              │
│ Implementation steps:                                                        │
│ 1. Observe AVAudioSession.interruptionNotification for phone calls           │
│ 2. Auto-pause recording on interruption .began                               │
│ 3. Auto-resume on interruption .ended (if .shouldResume)                     │
│ 4. Observe SwiftUI .scenePhase for background/inactive states                │
│ 5. Call stopRecording() and save session on .background                      │
│ 6. Show resume option on return to foreground                                │
│                                                                              │
│ Acceptance criteria:                                                         │
│ - Phone call auto-pauses recording                                           │
│ - Session auto-saves when app backgrounds                                    │
│ - Session auto-saves on app termination                                      │
│ - User can resume after interruption                                         │
│ - No audio data loss during interruptions                                    │
│                                                                              │
│ ---                                                                          │
│ Priority 4: WhisperKit Integration (CORE VALUE)                              │
│                                                                              │
│ Complexity: Complex | Dependencies: Manual SPM step                          │
│                                                                              │
│ Why fourth: Core transcription feature. Unlocks voice phrase kill switch and │
│  transcript polish.                                                          │
│                                                                              │
│ ⚠️ MANUAL STEP REQUIRED:                                                     │
│ WhisperKit cannot be added via command line. Must open Xcode:                │
│ 1. Open FlowDoc.xcodeproj in Xcode                                           │
│ 2. File → Add Package Dependencies                                           │
│ 3. Enter: https://github.com/argmaxinc/WhisperKit.git                        │
│ 4. Select version ≥ 0.15.0                                                   │
│ 5. Add to FlowDoc target                                                     │
│                                                                              │
│ Files to modify:                                                             │
│ - Services/TranscriptionEngine.swift - Replace stub with WhisperKit          │
│ implementation                                                               │
│ - Views/Recording/RecordingView.swift - Connect real-time transcript updates │
│ - Services/AudioRecorder.swift - Send audio chunks to transcription engine   │
│                                                                              │
│ Implementation steps:                                                        │
│ 1. Add WhisperKit SPM dependency (manual Xcode step)                         │
│ 2. Update TranscriptionEngine to load Whisper model on init                  │
│ 3. Implement transcribe(audioURL:) method using WhisperKit                   │
│ 4. Set up audio chunk buffering in AudioRecorder (30s rolling buffer)        │
│ 5. Send chunks to TranscriptionEngine during recording                       │
│ 6. Update RecordingView to display real Segment objects                      │
│ 7. Save segments to DatabaseManager on creation                              │
│                                                                              │
│ Acceptance criteria:                                                         │
│ - WhisperKit package added successfully                                      │
│ - Model downloads on first run (~200MB, user approves)                       │
│ - Audio transcribes to real Segment objects                                  │
│ - Segments appear in RecordingView live transcript                           │
│ - Segments persist to database                                               │
│ - Latency: <5s for short utterances (per specs)                              │
│                                                                              │
│ Notes:                                                                       │
│ - Target model: base.en (142MB, good accuracy/speed tradeoff)                │
│ - Use computeUnits: .cpuAndNeuralEngine for performance                      │
│ - Handle model download errors gracefully                                    │
│                                                                              │
│ ---                                                                          │
│ Priority 5: Transcript Display Polish (UX)                                   │
│                                                                              │
│ Complexity: Simple | Dependencies: Priority 4 (WhisperKit)                   │
│                                                                              │
│ Why fifth: Makes transcription output more usable. Quick win after           │
│ WhisperKit works.                                                            │
│                                                                              │
│ Files to modify:                                                             │
│ - Views/Recording/TranscriptRow.swift - Format timestamps as HH:MM:SS        │
│ - Views/Recording/RecordingView.swift - Improve auto-scroll behavior         │
│ - Views/Detail/SessionDetailView.swift - Add search/filter UI                │
│                                                                              │
│ Implementation steps:                                                        │
│ 1. Format timestamps as "MM:SS" (under 1 hour) or "HH:MM:SS"                 │
│ 2. Implement auto-scroll to latest segment (only if user hasn't scrolled up) │
│ 3. Add visual indicator for auto-scroll state                                │
│ 4. Polish TranscriptRow styling (match UI/UX Specs)                          │
│ 5. Add search bar in SessionDetailView                                       │
│ 6. Filter segments by search term                                            │
│                                                                              │
│ Acceptance criteria:                                                         │
│ - Timestamps display clearly (gray, small font)                              │
│ - Transcript auto-scrolls during recording                                   │
│ - User can manually scroll up to read history                                │
│ - Returning to bottom re-enables auto-scroll                                 │
│ - Search works in SessionDetailView                                          │
│                                                                              │
│ ---                                                                          │
│ Priority 6: Kill Switch Implementation (PRIVACY)                             │
│                                                                              │
│ Complexity: Moderate | Dependencies: Priority 4 for voice phrase variant     │
│                                                                              │
│ Why sixth: Nice-to-have privacy feature. Volume button version is            │
│ independent.                                                                 │
│                                                                              │
│ Files to modify:                                                             │
│ - Services/KillSwitchDetector.swift - Implement volume button monitoring     │
│ - Services/AudioRecorder.swift - Integrate kill switch detection             │
│ - Views/Recording/RecordingView.swift - Show kill switch activation feedback │
│                                                                              │
│ Implementation steps:                                                        │
│ 1. Implement volume button KVO in KillSwitchDetector                         │
│ 2. Track rapid 3-press within 1.5 second window                              │
│ 3. Fire onTrigger callback on detection                                      │
│ 4. Wire AudioRecorder to stop recording on trigger                           │
│ 5. Show brief "Kill switch activated" badge in RecordingView                 │
│ 6. (Optional) Add voice phrase detection using WhisperKit                    │
│                                                                              │
│ Acceptance criteria:                                                         │
│ - Volume down 3x within 1.5s stops recording                                 │
│ - Session ends cleanly (no data loss)                                        │
│ - Visual feedback shows kill switch activated                                │
│ - User can start new session after kill switch                               │
│                                                                              │
│ Notes:                                                                       │
│ - Voice phrase variant ("stop recording") depends on WhisperKit              │
│ - Can implement volume button version first, add voice later                 │
│                                                                              │
│ ---                                                                          │
│ Priority 7: Error Handling & Empty States (POLISH)                           │
│                                                                              │
│ Complexity: Simple | Dependencies: None (ongoing)                            │
│                                                                              │
│ Why last: Improves robustness. Can be done incrementally alongside other     │
│ features.                                                                    │
│                                                                              │
│ Files to modify:                                                             │
│ - Views/Home/HomeView.swift - Empty state when no sessions                   │
│ - Views/Recording/RecordingView.swift - Permission denied state              │
│ - Services/AudioRecorder.swift - Error alerts for recording failures         │
│ - Services/TranscriptionEngine.swift - Error alerts for model load failures  │
│                                                                              │
│ Implementation steps:                                                        │
│ 1. Add empty state to HomeView ("No sessions yet, tap + to start")           │
│ 2. Add permission prompt UI if mic access denied                             │
│ 3. Show alert if AudioRecorder.startRecording() fails                        │
│ 4. Show alert if TranscriptionEngine model fails to load                     │
│ 5. Log all errors to console (not external services)                         │
│ 6. Follow UI/UX Specs for error styling                                      │
│                                                                              │
│ Acceptance criteria:                                                         │
│ - Empty states show helpful guidance                                         │
│ - Permission denied shows clear prompt                                       │
│ - Recording errors show user-friendly alerts                                 │
│ - Transcription errors show clear messages                                   │
│ - All errors logged locally only (privacy)                                   │
│                                                                              │
│ ---                                                                          │
│ Recommended Build Order Summary                                              │
│                                                                              │
│ 1. Camera Photo Capture (Priority 1) - Quick win, immediate value            │
│ 2. Background Recording (Priority 2) - Critical for usability                │
│ 3. Auto-Save on Interruption (Priority 3) - Robustness, pairs with #2        │
│ 4. WhisperKit Integration (Priority 4) - Core transcription feature          │
│ 5. Transcript Polish (Priority 5) - UX improvements after transcription      │
│ works                                                                        │
│ 6. Kill Switch (Priority 6) - Privacy feature, optional voice phrase         │
│ 7. Error Handling (Priority 7) - Ongoing polish, test after each feature     │
│                                                                              │
│ Minimum Viable Product (MVP)                                                 │
│                                                                              │
│ To ship Phase 1 MVP, MUST complete:                                          │
│ - ✅ Priorities 1-5 (camera, background, interruption, transcription,        │
│ transcript polish)                                                           │
│ - ✅ Basic error handling (Priority 7)                                       │
│                                                                              │
│ Priorities 6 (kill switch) is nice-to-have but not critical for MVP.         │
│                                                                              │
│ Verification Strategy                                                        │
│                                                                              │
│ After implementing each feature:                                             │
│ 1. Build: Run xcodebuild -scheme FlowDoc -destination 'platform=iOS          │
│ Simulator,id=95638297-6C07-4134-855A-ACA7771CEC50' -configuration Debug      │
│ 2. Test: Run on iPhone 17 Pro simulator (iOS 26.2)                           │
│ 3. Verify: Test happy path + edge cases (permissions, interruptions,         │
│ backgrounding)                                                               │
│ 4. Review: Use verifier-flowdoc agent to check for privacy/performance       │
│ issues                                                                       │
│                                                                              │
│ Performance Targets (from Technical Specifications)                          │
│                                                                              │
│ - Audio recording startup: <100ms                                            │
│ - Transcription latency: <5s for short utterances                            │
│ - Database operations: <100ms                                                │
│ - UI scrolling: 60fps, no main thread blocking                               │
│                                                                              │
│ Privacy Guardrails                                                           │
│                                                                              │
│ - ❌ No networking (local-only processing)                                   │
│ - ❌ No external logging of audio/transcripts                                │
│ - ❌ No cloud sync                                                           │
│ - ✅ User data stays in app sandbox (Documents directory)                    │
│ - ✅ Print statements only (local console)                                   │
│                                                                              │
│ ---                                                                          │
│ Next Step                                                                    │
│                                                                              │
│ Recommended: Start with Priority 1: Camera Photo Capture Integration         │
│                                                                              │
│ This is a quick win that:                                                    │
│ - Provides immediate user value (capture session photos)                     │
│ - Builds on existing CameraController                                        │
│ - Has no dependencies                                                        │
│ - Doesn't block other features                                               │
│ - Tests our DatabaseManager media persistence                                │
│                                                                              │
│ After camera capture works, tackle Priorities 2 & 3 together (background     │
│ recording + auto-save) as a critical reliability pair.
