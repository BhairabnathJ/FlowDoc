# Technical Specifications: AI Teammate Documentation App
**Project Codename:** FlowDoc (Working Title)
**Version:** 1.0 MVP
**Platform:** iOS 16.0+
**Last Updated:** February 4, 2026

---

## 1. EXECUTIVE SUMMARY

### 1.1 Product Overview
FlowDoc is an always-on AI teammate for hardware teams that captures work sessions through continuous audio transcription, proactively suggests documentation moments, and enables intelligent visual capture of hardware configurations. The app runs entirely on-device using open-source models, ensuring zero API costs and complete privacy.

### 1.2 Core Value Proposition
- **Always-on documentation** without breaking flow
- **Zero cloud dependency** - all processing on-device
- **Proactive AI nudges** to capture critical moments
- **AR wire detection** for hardware reconstruction
- **Export to existing workflows** (Notion, Slack, etc.) via HTML

### 1.3 Target Users
- Hardware startup teams (IoT, robotics, electronics)
- University engineering labs
- Maker spaces and hardware hackers
- Field engineers and technicians

---

## 2. FEATURE SPECIFICATIONS

### 2.1 PHASE 1: AUDIO TRANSCRIPTION CORE (MVP - Weeks 1-3)

#### Feature 1.1: Always-On Audio Recording
**Description:** Background audio capture that persists even when app is closed or phone is locked.

**Technical Implementation:**
- **Framework:** AVFoundation (AVAudioSession + AVAudioRecorder)
- **Audio Format:** Linear PCM, 16kHz sample rate, mono channel
- **Buffer Size:** 30-second rolling buffer for Whisper processing
- **Background Mode:** Enable `audio` in `UIBackgroundModes` (Info.plist)

**Configuration:**
```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.record, mode: .default)
try session.setActive(true)

let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatLinearPCM,
    AVSampleRateKey: 16000,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false
]
```

**User Controls:**
- Tap "Start Session" button
- Persistent notification shows recording status
- Visual indicator (pulsing red dot in app UI)
- Session metadata: start time, duration, location (optional)

**File Storage:**
- Local SQLite database for session metadata
- Audio chunks stored in app Documents directory
- Auto-cleanup of audio files after transcription (user configurable)

**Battery Optimization:**
- Voice Activity Detection (VAD) to skip silence
- Adaptive sample rate (reduce to 8kHz during silence)
- Efficient buffer management

---

#### Feature 1.2: Real-Time Speech Transcription
**Description:** On-device speech-to-text conversion using Whisper model.

**Technical Implementation:**
- **Model:** WhisperKit (Swift native wrapper for whisper.cpp)
- **Model Size:** `base.en` (142MB) - good accuracy/speed tradeoff for iPhone 11+
- **Processing:** Streaming transcription with 1-2 second latency
- **Voice Activity Detection:** Silero VAD or WhisperKit built-in VAD

**Installation:**
```swift
// Swift Package Manager
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.15.0")
]
```

**Code Structure:**
```swift
import WhisperKit

class TranscriptionEngine {
    private var whisper: WhisperKit?
    
    func initialize() async throws {
        // Download model on first run (~140MB)
        whisper = try await WhisperKit(
            modelName: "base.en",
            computeUnits: .cpuAndNeuralEngine, // Use Neural Engine
            verbose: false
        )
    }
    
    func transcribe(audioURL: URL) async throws -> TranscriptResult {
        let result = try await whisper?.transcribe(
            audioPath: audioURL.path,
            decodeOptions: DecodingOptions(
                temperature: 0.0,
                topK: 5,
                usePrefillPrompt: true
            )
        )
        return result
    }
}

struct TranscriptResult {
    let text: String
    let segments: [Segment]
    let language: String
}

struct Segment {
    let id: Int
    let text: String
    let start: TimeInterval
    let end: TimeInterval
    let confidence: Float
}
```

**Performance Targets:**
- iPhone 17 Pro Max: 0.3-0.5s latency per 30s chunk
- iPhone 11 Pro: 1-2s latency per 30s chunk
- Real-time factor: <0.5x (processes faster than realtime)

**Accuracy Features:**
- Speaker diarization (detect multiple speakers)
- Timestamped segments (paragraph-level)
- Confidence scores per segment
- Custom vocabulary injection (technical terms, part numbers)

---

#### Feature 1.3: Privacy Kill Switch
**Description:** User-controlled mechanism to pause recording for sensitive conversations.

**Technical Implementation:**
- **Trigger Methods:**
  1. Custom voice phrase detection ("BIG APPLE BAZINGA" default, user customizable)
  2. Hardware button (volume down 3x rapid press)
  3. In-app pause button
  4. Automatic pause on phone call detection

**Voice Phrase Detection:**
```swift
import Speech

class KillSwitchDetector {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func startListening(audioEngine: AVAudioEngine, onTrigger: @escaping () -> Void) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        
        recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
            guard let result = result else { return }
            let transcript = result.bestTranscription.formattedString.lowercased()
            
            if transcript.contains("big apple bazinga") {
                onTrigger()
            }
        }
    }
}
```

**Visual Indicators:**
- Recording: Pulsing red dot + persistent notification
- Paused: Yellow pause icon + "Recording Paused" notification
- Stopped: Gray stop icon

**Data Handling:**
- Paused audio is NOT saved or transcribed
- Gap indicator in transcript: `[Recording paused: 5:23 - 5:45]`
- Resume creates new transcript segment

**Settings:**
- Customize trigger phrase
- Enable/disable hardware button trigger
- Auto-pause on incoming calls (default: ON)
- Privacy timeout (auto-stop after X hours, default: 4 hours)

---

#### Feature 1.4: Manual Photo/Video Capture
**Description:** In-app camera for capturing visual documentation during sessions.

**Technical Implementation:**
- **Framework:** AVFoundation (AVCaptureSession)
- **Camera Access:** Request permission on first use
- **Capture Modes:**
  1. Photo (still image)
  2. Video (up to 30 seconds)
  3. Burst mode (3 rapid photos)

**Camera UI:**
```swift
import AVFoundation
import SwiftUI

struct CameraView: View {
    @StateObject private var camera = CameraController()
    
    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
            
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    Button(action: camera.capturePhoto) {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)
                    }
                    
                    Button(action: camera.startRecording) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 70, height: 70)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

class CameraController: ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureMovieFileOutput()
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}
```

**Media Storage:**
- Photos: JPEG, max 4K resolution
- Videos: H.264, 1080p, 30fps
- Stored in app Documents directory
- Linked to transcript timestamp
- Optional caption/annotation per media item

**Media Metadata:**
```swift
struct MediaCapture {
    let id: UUID
    let sessionID: UUID
    let type: MediaType // .photo, .video
    let timestamp: Date
    let transcriptOffset: TimeInterval // seconds into session
    let fileURL: URL
    let thumbnail: UIImage?
    var caption: String?
    var tags: [String]
}
```

---

#### Feature 1.5: HTML Export System
**Description:** Generate structured HTML documents that can be imported into Notion, Obsidian, or any markdown-compatible tool.

**Technical Implementation:**

**HTML Template Structure:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Session: {{session_date}} {{session_time}}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
        .summary { background: #f5f5f5; padding: 20px; border-radius: 8px; }
        .transcript { line-height: 1.8; }
        .timestamp { color: #666; font-weight: 600; }
        .media-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 16px; }
        img { max-width: 100%; border-radius: 4px; }
    </style>
</head>
<body>
    <h1>🎙️ Session Transcript - {{date}}</h1>
    
    <div class="summary">
        <h2>📋 Summary</h2>
        <p><strong>Duration:</strong> {{duration}}</p>
        <p><strong>Location:</strong> {{location}}</p>
        <p><strong>Participants:</strong> {{speakers}}</p>
    </div>
    
    <h2>💡 Key Points</h2>
    <ul>
        {{#key_points}}
        <li>{{.}}</li>
        {{/key_points}}
    </ul>
    
    <h2>📸 Media Captured</h2>
    <div class="media-grid">
        {{#media}}
        <figure>
            <img src="{{url}}" alt="{{caption}}">
            <figcaption>{{caption}} - {{timestamp}}</figcaption>
        </figure>
        {{/media}}
    </div>
    
    <h2>📝 Full Transcript</h2>
    <div class="transcript">
        {{#segments}}
        <p>
            <span class="timestamp">[{{timestamp}}]</span>
            {{#speaker}}Speaker {{speaker_id}}: {{/speaker}}
            {{text}}
        </p>
        {{/segments}}
    </div>
    
    <h2>✅ Action Items</h2>
    <ul>
        {{#action_items}}
        <li><strong>@{{assignee}}:</strong> {{task}}</li>
        {{/action_items}}
    </ul>
    
    <hr>
    <p><small>Generated by FlowDoc on {{export_timestamp}}</small></p>
</body>
</html>
```

**Export Implementation:**
```swift
class HTMLExporter {
    func generateHTML(from session: Session) -> String {
        let template = loadTemplate()
        
        let data: [String: Any] = [
            "date": session.startTime.formatted(),
            "duration": session.duration.formatted(),
            "location": session.location ?? "Unknown",
            "speakers": session.speakers.joined(separator: ", "),
            "key_points": extractKeyPoints(session.transcript),
            "media": session.mediaCaptures.map { mediaDict($0) },
            "segments": session.transcript.segments.map { segmentDict($0) },
            "action_items": extractActionItems(session.transcript),
            "export_timestamp": Date().formatted()
        ]
        
        return renderTemplate(template, with: data)
    }
    
    func exportOptions() -> [ExportOption] {
        return [
            .copyToClipboard,    // Copy HTML to clipboard
            .saveAsFile,         // Download .html file
            .shareSheet          // iOS share sheet
        ]
    }
}

enum ExportOption {
    case copyToClipboard
    case saveAsFile
    case shareSheet
}
```

**Image Handling:**
- Option 1: Base64 embed (offline-compatible, large file size)
- Option 2: Bundle images in zip with HTML
- Default: Base64 for <5 images, zip for 5+ images

---

### 2.2 PHASE 2: AI INTELLIGENCE (Weeks 4-6)

#### Feature 2.1: AI-Generated Summaries & Key Points
**Description:** Automatic extraction of important information using on-device LLM.

**Technical Implementation:**
- **Model:** Qwen2.5-0.6B-Instruct (600MB, quantized to INT4 ~400MB)
- **Alternative:** Phi-3-mini (3.8B) for better quality on iPhone 15+
- **Runtime:** llama.cpp with Swift bindings

**Installation:**
```bash
# Download model (one-time, on Mac)
curl -LO https://huggingface.co/Qwen/Qwen2.5-0.6B-Instruct-GGUF/resolve/main/qwen2.5-0.6b-instruct-q4_k_m.gguf

# Add to Xcode project
# Drag .gguf file into Xcode → Copy items if needed → Add to target
```

**Swift Implementation:**
```swift
import llama

class SummaryEngine {
    private var context: OpaquePointer?
    
    func initialize() {
        let modelPath = Bundle.main.path(forResource: "qwen2.5-0.6b-instruct-q4_k_m", ofType: "gguf")!
        
        var params = llama_context_default_params()
        params.n_ctx = 2048 // Context window
        params.n_threads = 4 // Use 4 CPU threads
        
        context = llama_init_from_file(modelPath, params)
    }
    
    func generateSummary(transcript: String) async -> Summary {
        let prompt = """
        Extract key points and action items from this hardware team meeting transcript.
        
        Transcript:
        \(transcript)
        
        Provide:
        1. 3-5 key discussion points
        2. Any action items with assignees
        3. Technical specs or decisions mentioned
        
        Format as JSON.
        """
        
        let response = await generate(prompt: prompt)
        return parseSummary(response)
    }
    
    private func generate(prompt: String) async -> String {
        // llama.cpp inference logic
        // Returns generated text
    }
}

struct Summary {
    let keyPoints: [String]
    let actionItems: [ActionItem]
    let technicalSpecs: [String: String] // e.g., "voltage": "3.3V"
}

struct ActionItem {
    let task: String
    let assignee: String?
    let priority: Priority
}
```

**Performance:**
- iPhone 17 Pro: ~40 tokens/sec
- iPhone 11 Pro: ~15 tokens/sec
- Summary generation: 30-60 seconds for 1-hour transcript

---

#### Feature 2.2: Proactive AI Nudges
**Description:** Context-aware suggestions to capture photos, videos, or important moments.

**Technical Implementation:**

**Keyword Detection:**
```swift
class NudgeEngine {
    private let keywords: [NudgeType: [String]] = [
        .captureVisual: [
            "wiring", "breadboard", "circuit", "schematic",
            "setup", "configuration", "assembly", "final version",
            "show you", "take a look"
        ],
        .decisionMade: [
            "decided", "going with", "final decision",
            "we'll use", "settled on"
        ],
        .actionable: [
            "need to", "should", "must", "have to",
            "follow up", "next step"
        ],
        .technicalSpec: [
            "voltage", "current", "resistance", "frequency",
            "sensor", "GPIO", "pin", "ohm", "volt", "amp"
        ]
    ]
    
    func analyzeSegment(_ segment: Segment) -> [Nudge] {
        var nudges: [Nudge] = []
        let text = segment.text.lowercased()
        
        for (type, words) in keywords {
            let matches = words.filter { text.contains($0) }
            if matches.count >= 2 { // At least 2 keyword matches
                nudges.append(Nudge(
                    type: type,
                    message: generateMessage(for: type),
                    timestamp: segment.start,
                    confidence: Float(matches.count) / Float(words.count)
                ))
            }
        }
        
        return nudges
    }
    
    private func generateMessage(for type: NudgeType) -> String {
        switch type {
        case .captureVisual:
            return "📸 Sounds like you're discussing a setup. Want to capture a photo?"
        case .decisionMade:
            return "✅ Important decision detected. Mark this in your notes?"
        case .actionable:
            return "📋 Action item mentioned. Should we log this?"
        case .technicalSpec:
            return "🔧 Technical specs discussed. Document these details?"
        }
    }
}

enum NudgeType {
    case captureVisual
    case decisionMade
    case actionable
    case technicalSpec
}

struct Nudge {
    let type: NudgeType
    let message: String
    let timestamp: TimeInterval
    let confidence: Float
}
```

**Nudge Presentation:**
- Non-intrusive banner at bottom of screen
- Haptic feedback (light tap)
- Swipe up to act, swipe down to dismiss
- Auto-dismiss after 10 seconds if not interacted
- Snooze option ("Remind me in 2 minutes")

**User Settings:**
- Enable/disable nudges
- Customize sensitivity (aggressive, balanced, minimal)
- Exclude specific keywords
- Quiet hours (no nudges during specific times)

---

### 2.3 PHASE 3: VISUAL INTELLIGENCE (Weeks 7-10+)

#### Feature 3.1: AR Wire Detection & Highlighting
**Description:** Computer vision system that detects and labels individual wires in breadboard/circuit setups.

**Technical Implementation:**

**Model Pipeline:**
1. **Wire Detection:** YOLOv8-nano (custom trained on wire/breadboard images)
2. **Wire Segmentation:** MobileSAM (Segment Anything for mobile)
3. **Wire Tracking:** Optical flow + skeletonization
4. **Connection Mapping:** Graph analysis of wire endpoints

**YOLOv8 Training (On Mac):**
```bash
# Install Ultralytics
pip install ultralytics

# Prepare dataset
# Format: images/ and labels/ folders
# labels/*.txt format: class x_center y_center width height

# Train custom model
yolo train model=yolov8n.pt data=wires.yaml epochs=100 imgsz=640

# Export to CoreML
yolo export model=runs/detect/train/weights/best.pt format=coreml nms=True
```

**iOS Integration:**
```swift
import Vision
import CoreML

class WireDetector {
    private var model: VNCoreMLModel?
    
    func initialize() throws {
        let mlModel = try best(configuration: MLModelConfiguration())
        model = try VNCoreMLModel(for: mlModel.model)
    }
    
    func detectWires(in image: CVPixelBuffer) async -> [Wire] {
        guard let model = model else { return [] }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                return
            }
            
            // Process detected wires
            for observation in results where observation.confidence > 0.6 {
                let wire = Wire(
                    color: observation.labels[0].identifier,
                    boundingBox: observation.boundingBox,
                    confidence: observation.confidence
                )
                // Add to wire list
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: image)
        try? handler.perform([request])
        
        return detectedWires
    }
}

struct Wire {
    let id: UUID
    let color: WireColor
    let path: [CGPoint] // Traced path of wire
    let startPoint: Connection
    let endPoint: Connection
    let boundingBox: CGRect
    let confidence: Float
}
```

---

## 3. DATA ARCHITECTURE

### 3.1 Core Data Model

```swift
// Session entity
class Session {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval { endTime?.timeIntervalSince(startTime) ?? 0 }
    var location: String?
    var participants: [String]
    var transcript: Transcript
    var mediaCaptures: [MediaCapture]
    var summary: Summary?
    var tags: [String]
    var isArchived: Bool
}
```

### 3.2 Local Storage (SQLite)

```sql
-- sessions table
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    location TEXT,
    participants TEXT, -- JSON array
    tags TEXT, -- JSON array
    is_archived BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- segments table
CREATE TABLE segments (
    id TEXT PRIMARY KEY,
    transcript_id TEXT NOT NULL,
    text TEXT NOT NULL,
    start_time REAL NOT NULL,
    end_time REAL NOT NULL,
    speaker_id TEXT,
    confidence REAL,
    is_edited BOOLEAN DEFAULT 0,
    keywords TEXT, -- JSON array
    FOREIGN KEY (transcript_id) REFERENCES transcripts(id) ON DELETE CASCADE
);
```

---

## 4. PERFORMANCE REQUIREMENTS

### 4.1 Device Compatibility

| Device | Features |
|--------|----------|
| **iPhone 11 Pro** | Audio transcription, AI summaries (slower) |
| **iPhone 13 Pro** | All features with good performance |
| **iPhone 15 Pro+** | All features with Neural Engine acceleration |
| **iPhone 17 Pro Max** | Optimal performance, real-time AR |

### 4.2 Performance Targets

**Transcription:**
- Real-time factor: <0.5x (processes 30s audio in <15s)
- Latency: 1-3 seconds per segment
- Accuracy: >90% WER (Word Error Rate) for clear audio

**Battery Life:**
- 4-hour continuous session should consume <40% battery
- Background recording: <5% battery drain per hour

**Storage:**
- Session data: ~100-200 MB per hour
- Models: ~600 MB one-time download

---

## 5. PRIVACY & SECURITY

### 5.1 Data Privacy Principles
- **Local-first:** All processing on-device, no cloud sync required
- **User control:** Explicit permission for microphone, camera, location
- **Data retention:** User configurable (7 days, 30 days, forever)
- **Export only:** Data leaves device only when user exports

### 5.2 Permissions Required
```xml
<key>NSMicrophoneUsageDescription</key>
<string>FlowDoc needs microphone access to transcribe your work sessions.</string>

<key>NSCameraUsageDescription</key>
<string>FlowDoc needs camera access to capture photos and videos.</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

---

## 6. DEVELOPMENT ROADMAP

### Phase 1: MVP (Weeks 1-3)
- [ ] Audio recording with background support
- [ ] WhisperKit integration
- [ ] Basic UI
- [ ] Kill switch
- [ ] Manual photo capture
- [ ] SQLite database
- [ ] HTML export

### Phase 2: Intelligence (Weeks 4-6)
- [ ] llama.cpp integration
- [ ] AI summary generation
- [ ] Keyword-based nudge system
- [ ] Speaker diarization
- [ ] Enhanced HTML templates

### Phase 3: Visual Intelligence (Weeks 7-10)
- [ ] YOLOv8 training
- [ ] AR overlay system
- [ ] Wire detection
- [ ] Schematic generation

---

**END OF TECHNICAL SPECIFICATIONS**
