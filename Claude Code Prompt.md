# Claude Code Build Prompt: FlowDoc iOS App
**Complete Step-by-Step Instructions for AI-Assisted Development**
**Version:** 1.0 MVP
**Last Updated:** February 4, 2026

---

## 🎯 OVERVIEW

You are building **FlowDoc**, an iOS app that acts as an AI teammate for hardware teams. It continuously records and transcribes work sessions, proactively suggests documentation moments, and uses computer vision to document circuit setups.

**Key Differentiators:**
- 100% on-device processing (no cloud, no API costs)
- Always-on background audio recording
- Real-time transcription with WhisperKit
- Proactive AI nudges using on-device LLM
- AR wire detection for hardware documentation

---

## 📋 PREREQUISITES

Before you start, ensure you have:
- [x] Xcode 15.0+ installed
- [x] Mac with macOS 14.0+ (Sonoma)
- [x] iPhone 11 Pro or newer for testing
- [x] `technical_specifications.md` uploaded to this chat
- [x] `ui_ux_specifications.md` uploaded to this chat
- [x] Apple Developer account (for device testing)

---

## 🏗️ PROJECT STRUCTURE

```
FlowDoc/
├── FlowDoc.xcodeproj
├── FlowDoc/
│   ├── App/
│   │   ├── FlowDocApp.swift           # App entry point
│   │   └── ContentView.swift          # Root view
│   │
│   ├── Models/
│   │   ├── Session.swift              # Session data model
│   │   ├── Transcript.swift           # Transcript model
│   │   ├── Segment.swift              # Transcript segment
│   │   └── MediaCapture.swift         # Photo/video metadata
│   │
│   ├── Services/
│   │   ├── AudioRecorder.swift        # Audio recording service
│   │   ├── TranscriptionEngine.swift  # WhisperKit integration
│   │   ├── DatabaseManager.swift      # SQLite operations
│   │   ├── KillSwitchDetector.swift   # Privacy pause mechanism
│   │   └── HTMLExporter.swift         # Export to HTML
│   │
│   ├── Views/
│   │   ├── Home/
│   │   │   ├── HomeView.swift         # Session list
│   │   │   └── SessionCard.swift      # Session list item
│   │   │
│   │   ├── Recording/
│   │   │   ├── RecordingView.swift    # Active recording screen
│   │   │   └── TranscriptRow.swift    # Transcript segment row
│   │   │
│   │   ├── Detail/
│   │   │   ├── SessionDetailView.swift # Session detail
│   │   │   └── MediaGridView.swift     # Photo/video grid
│   │   │
│   │   └── Components/
│   │       ├── PrimaryButton.swift
│   │       ├── RecordingDot.swift
│   │       ├── StatusBadge.swift
│   │       └── TagView.swift
│   │
│   ├── Design/
│   │   ├── DesignTokens.swift         # Color, typography, spacing
│   │   └── ColorExtensions.swift      # Hex color init
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets            # Images, icons
│   │   └── Info.plist                 # Permissions, background modes
│   │
│   └── Database/
│       └── schema.sql                 # SQLite schema
│
└── Models/                             # CoreML models (added later)
    └── whisper-base-en.mlmodelc       # WhisperKit model
```

---

## 🚀 BUILD INSTRUCTIONS

### PHASE 1: MVP (Weeks 1-3)

---

### **STEP 1: Xcode Project Setup**

**What to do:**
1. Open Xcode
2. File → New → Project
3. Choose "iOS App"
4. Project settings:
   - Product Name: `FlowDoc`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Storage: None (we'll use SQLite)
   - Include Tests: Yes

**Configuration:**
- Deployment Target: iOS 16.0+
- Team: Select your developer account
- Bundle Identifier: `com.yourname.flowdoc`

**Info.plist Additions:**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>FlowDoc needs microphone access to transcribe your work sessions.</string>

<key>NSCameraUsageDescription</key>
<string>FlowDoc needs camera access to capture photos and videos during sessions.</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>microphone</string>
</array>
```

---

### **STEP 2: Install Dependencies (Swift Package Manager)**

**Add WhisperKit:**
1. File → Add Package Dependencies
2. Enter URL: `https://github.com/argmaxinc/WhisperKit.git`
3. Version: `0.15.0` or later
4. Add to target: FlowDoc

**Add SQLite.swift:**
1. File → Add Package Dependencies
2. Enter URL: `https://github.com/stephencelis/SQLite.swift.git`
3. Version: `0.15.0` or later
4. Add to target: FlowDoc

---

### **STEP 3: Create Design System**

**Create `Design/DesignTokens.swift`:**

```swift
import SwiftUI

struct DesignTokens {
    struct Colors {
        // Light mode
        static let backgroundPrimaryLight = Color(hex: "#FCFCF9")
        static let backgroundSecondaryLight = Color(hex: "#FFFFFF")
        static let textPrimaryLight = Color(hex: "#13343B")
        static let textSecondaryLight = Color(hex: "#626C71")
        static let accentPrimaryLight = Color(hex: "#21808D")
        static let stateRecordingLight = Color(hex: "#C0152F")
        
        // Dark mode
        static let backgroundPrimaryDark = Color(hex: "#1F2121")
        static let backgroundSecondaryDark = Color(hex: "#262828")
        static let textPrimaryDark = Color(hex: "#F5F5F5")
        static let textSecondaryDark = Color(hex: "#A7A9A9").opacity(0.7)
        static let accentPrimaryDark = Color(hex: "#32B8C6")
        static let stateRecordingDark = Color(hex: "#FF5459")
        
        // Adaptive colors
        static func backgroundPrimary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? backgroundPrimaryDark : backgroundPrimaryLight
        }
        
        static func textPrimary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? textPrimaryDark : textPrimaryLight
        }
        
        static func accentPrimary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? accentPrimaryDark : accentPrimaryLight
        }
    }
    
    struct Typography {
        static let display = Font.system(size: 30, weight: .semibold)
        static let title1 = Font.system(size: 24, weight: .semibold)
        static let title2 = Font.system(size: 20, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let bodyMedium = Font.system(size: 16, weight: .medium)
        static let small = Font.system(size: 14, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let tiny = Font.system(size: 11, weight: .medium)
    }
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    struct CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
    }
}
```

**Create `Design/ColorExtensions.swift`:**

```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

---

### **STEP 4: Create Data Models**

**Create `Models/Session.swift`:**

```swift
import Foundation

struct Session: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var location: String?
    var participants: [String]
    var tags: [String]
    var isArchived: Bool
    
    var duration: TimeInterval {
        guard let end = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return end.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    init(id: UUID = UUID(), startTime: Date = Date(), endTime: Date? = nil, location: String? = nil, participants: [String] = [], tags: [String] = [], isArchived: Bool = false) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.participants = participants
        self.tags = tags
        self.isArchived = isArchived
    }
}
```

**Create `Models/Segment.swift`:**

```swift
import Foundation

struct Segment: Identifiable, Codable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    var speakerID: String?
    let confidence: Float
    var isEdited: Bool
    
    var formattedTimestamp: String {
        let hours = Int(startTime) / 3600
        let minutes = Int(startTime) / 60 % 60
        let seconds = Int(startTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    init(id: UUID = UUID(), text: String, startTime: TimeInterval, endTime: TimeInterval, speakerID: String? = nil, confidence: Float = 1.0, isEdited: Bool = false) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.speakerID = speakerID
        self.confidence = confidence
        self.isEdited = isEdited
    }
}
```

**Create `Models/Transcript.swift`:**

```swift
import Foundation

struct Transcript: Identifiable, Codable {
    let id: UUID
    let sessionID: UUID
    var segments: [Segment]
    
    var fullText: String {
        segments.map { $0.text }.joined(separator: " ")
    }
    
    init(id: UUID = UUID(), sessionID: UUID, segments: [Segment] = []) {
        self.id = id
        self.sessionID = sessionID
        self.segments = segments
    }
}
```

**Create `Models/MediaCapture.swift`:**

```swift
import Foundation
import UIKit

enum MediaType: String, Codable {
    case photo
    case video
}

struct MediaCapture: Identifiable, Codable {
    let id: UUID
    let sessionID: UUID
    let type: MediaType
    let timestamp: Date
    let transcriptOffset: TimeInterval
    let fileURL: URL
    var caption: String?
    var tags: [String]
    
    init(id: UUID = UUID(), sessionID: UUID, type: MediaType, timestamp: Date = Date(), transcriptOffset: TimeInterval, fileURL: URL, caption: String? = nil, tags: [String] = []) {
        self.id = id
        self.sessionID = sessionID
        self.type = type
        self.timestamp = timestamp
        self.transcriptOffset = transcriptOffset
        self.fileURL = fileURL
        self.caption = caption
        self.tags = tags
    }
}
```

---

### **STEP 5: Build Database Manager**

**Create `Services/DatabaseManager.swift`:**

```swift
import Foundation
import SQLite

class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    
    // Tables
    private let sessions = Table("sessions")
    private let transcripts = Table("transcripts")
    private let segments = Table("segments")
    private let mediaCaptures = Table("media_captures")
    
    // Session columns
    private let sessionId = Expression<String>("id")
    private let sessionStartTime = Expression<Date>("start_time")
    private let sessionEndTime = Expression<Date?>("end_time")
    private let sessionLocation = Expression<String?>("location")
    private let sessionParticipants = Expression<String>("participants") // JSON
    private let sessionTags = Expression<String>("tags") // JSON
    private let sessionIsArchived = Expression<Bool>("is_archived")
    
    // Transcript columns
    private let transcriptId = Expression<String>("id")
    private let transcriptSessionId = Expression<String>("session_id")
    
    // Segment columns
    private let segmentId = Expression<String>("id")
    private let segmentTranscriptId = Expression<String>("transcript_id")
    private let segmentText = Expression<String>("text")
    private let segmentStartTime = Expression<Double>("start_time")
    private let segmentEndTime = Expression<Double>("end_time")
    private let segmentSpeakerId = Expression<String?>("speaker_id")
    private let segmentConfidence = Expression<Double>("confidence")
    private let segmentIsEdited = Expression<Bool>("is_edited")
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first!
        
        do {
            db = try Connection("\(path)/flowdoc.sqlite3")
            createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    private func createTables() {
        do {
            // Sessions table
            try db?.run(sessions.create(ifNotExists: true) { t in
                t.column(sessionId, primaryKey: true)
                t.column(sessionStartTime)
                t.column(sessionEndTime)
                t.column(sessionLocation)
                t.column(sessionParticipants)
                t.column(sessionTags)
                t.column(sessionIsArchived, defaultValue: false)
            })
            
            // Transcripts table
            try db?.run(transcripts.create(ifNotExists: true) { t in
                t.column(transcriptId, primaryKey: true)
                t.column(transcriptSessionId)
                t.foreignKey(transcriptSessionId, references: sessions, sessionId, delete: .cascade)
            })
            
            // Segments table
            try db?.run(segments.create(ifNotExists: true) { t in
                t.column(segmentId, primaryKey: true)
                t.column(segmentTranscriptId)
                t.column(segmentText)
                t.column(segmentStartTime)
                t.column(segmentEndTime)
                t.column(segmentSpeakerId)
                t.column(segmentConfidence, defaultValue: 1.0)
                t.column(segmentIsEdited, defaultValue: false)
                t.foreignKey(segmentTranscriptId, references: transcripts, transcriptId, delete: .cascade)
            })
            
            print("Database tables created successfully")
        } catch {
            print("Create tables error: \(error)")
        }
    }
    
    // MARK: - Session Operations
    
    func saveSession(_ session: Session) {
        do {
            let participantsJSON = try JSONEncoder().encode(session.participants)
            let tagsJSON = try JSONEncoder().encode(session.tags)
            
            let insert = sessions.insert(
                sessionId <- session.id.uuidString,
                sessionStartTime <- session.startTime,
                sessionEndTime <- session.endTime,
                sessionLocation <- session.location,
                sessionParticipants <- String(data: participantsJSON, encoding: .utf8)!,
                sessionTags <- String(data: tagsJSON, encoding: .utf8)!,
                sessionIsArchived <- session.isArchived
            )
            
            try db?.run(insert)
            print("Session saved: \(session.id)")
        } catch {
            print("Save session error: \(error)")
        }
    }
    
    func fetchAllSessions() -> [Session] {
        var result: [Session] = []
        
        do {
            guard let db = db else { return result }
            
            for row in try db.prepare(sessions.order(sessionStartTime.desc)) {
                let participants = try JSONDecoder().decode([String].self, from: row[sessionParticipants].data(using: .utf8)!)
                let tags = try JSONDecoder().decode([String].self, from: row[sessionTags].data(using: .utf8)!)
                
                let session = Session(
                    id: UUID(uuidString: row[sessionId])!,
                    startTime: row[sessionStartTime],
                    endTime: row[sessionEndTime],
                    location: row[sessionLocation],
                    participants: participants,
                    tags: tags,
                    isArchived: row[sessionIsArchived]
                )
                
                result.append(session)
            }
        } catch {
            print("Fetch sessions error: \(error)")
        }
        
        return result
    }
    
    // MARK: - Segment Operations
    
    func saveSegment(_ segment: Segment, transcriptId: UUID) {
        do {
            let insert = segments.insert(
                segmentId <- segment.id.uuidString,
                segmentTranscriptId <- transcriptId.uuidString,
                segmentText <- segment.text,
                segmentStartTime <- segment.startTime,
                segmentEndTime <- segment.endTime,
                segmentSpeakerId <- segment.speakerID,
                segmentConfidence <- Double(segment.confidence),
                segmentIsEdited <- segment.isEdited
            )
            
            try db?.run(insert)
        } catch {
            print("Save segment error: \(error)")
        }
    }
    
    func fetchSegments(for transcriptId: UUID) -> [Segment] {
        var result: [Segment] = []
        
        do {
            guard let db = db else { return result }
            
            let query = segments.filter(segmentTranscriptId == transcriptId.uuidString)
                .order(segmentStartTime.asc)
            
            for row in try db.prepare(query) {
                let segment = Segment(
                    id: UUID(uuidString: row[segmentId])!,
                    text: row[segmentText],
                    startTime: row[segmentStartTime],
                    endTime: row[segmentEndTime],
                    speakerID: row[segmentSpeakerId],
                    confidence: Float(row[segmentConfidence]),
                    isEdited: row[segmentIsEdited]
                )
                
                result.append(segment)
            }
        } catch {
            print("Fetch segments error: \(error)")
        }
        
        return result
    }
}
```

---

### **STEP 6: Build Audio Recording Service**

**Create `Services/AudioRecorder.swift`:**

```swift
import Foundation
import AVFoundation

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var currentSession: Session?
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.record, mode: .default, options: [.allowBluetooth])
            try session.setActive(true)
            print("Audio session configured successfully")
        } catch {
            print("Audio session setup error: \(error)")
        }
    }
    
    func startRecording() {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else {
                print("Microphone permission denied")
                return
            }
            
            Task { @MainActor in
                self?.beginRecording()
            }
        }
    }
    
    private func beginRecording() {
        let newSession = Session(
            startTime: Date(),
            participants: [],
            tags: []
        )
        
        currentSession = newSession
        DatabaseManager.shared.saveSession(newSession)
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(newSession.id.uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            recordingStartTime = Date()
            
            // Start timer for UI updates
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                }
            }
            
            print("Recording started: \(audioFilename)")
        } catch {
            print("Recording start error: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        
        if var session = currentSession {
            session.endTime = Date()
            // Update session in database
        }
        
        isRecording = false
        currentSession = nil
        
        print("Recording stopped")
    }
    
    func pauseRecording() {
        audioRecorder?.pause()
        isRecording = false
    }
    
    func resumeRecording() {
        audioRecorder?.record()
        isRecording = true
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
```

---

### **STEP 7: Build UI Components**

**Create `Views/Components/PrimaryButton.swift`:**

```swift
import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.backgroundPrimaryLight)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(DesignTokens.Colors.accentPrimary(for: colorScheme))
                .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }
}
```

**Create `Views/Components/RecordingDot.swift`:**

```swift
import SwiftUI

struct RecordingDot: View {
    @State private var isPulsing = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Circle()
            .fill(colorScheme == .dark ? DesignTokens.Colors.stateRecordingDark : DesignTokens.Colors.stateRecordingLight)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}
```

---

### **STEP 8: Build Home Screen**

**Create `Views/Home/HomeView.swift`:**

```swift
import SwiftUI

struct HomeView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var sessions: [Session] = []
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        if audioRecorder.isRecording, let session = audioRecorder.currentSession {
                            ActiveSessionCard(session: session, audioRecorder: audioRecorder)
                                .padding(.horizontal, DesignTokens.Spacing.lg)
                                .padding(.top, DesignTokens.Spacing.lg)
                        }
                        
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            Text("Recent Sessions")
                                .font(DesignTokens.Typography.title2)
                                .foregroundColor(DesignTokens.Colors.textPrimary(for: colorScheme))
                                .padding(.horizontal, DesignTokens.Spacing.lg)
                            
                            ForEach(sessions) { session in
                                SessionCard(session: session)
                                    .padding(.horizontal, DesignTokens.Spacing.lg)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                
                // FAB
                if !audioRecorder.isRecording {
                    Button(action: { audioRecorder.startRecording() }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("New Session")
                                .font(DesignTokens.Typography.bodyMedium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.lg)
                        .background(DesignTokens.Colors.accentPrimary(for: colorScheme))
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
            }
            .background(DesignTokens.Colors.backgroundPrimary(for: colorScheme))
            .navigationTitle("FlowDoc")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .onAppear {
            loadSessions()
        }
    }
    
    private func loadSessions() {
        sessions = DatabaseManager.shared.fetchAllSessions()
    }
}

struct ActiveSessionCard: View {
    let session: Session
    @ObservedObject var audioRecorder: AudioRecorder
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                RecordingDot()
                Text("Current Session")
                    .font(DesignTokens.Typography.title2)
                Spacer()
            }
            
            Text(session.formattedDuration)
                .font(DesignTokens.Typography.display)
                .foregroundColor(DesignTokens.Colors.textPrimary(for: colorScheme))
            
            HStack(spacing: DesignTokens.Spacing.md) {
                Button(action: { audioRecorder.pauseRecording() }) {
                    Label("Pause", systemImage: "pause.circle.fill")
                        .font(DesignTokens.Typography.body)
                }
                
                Button(action: { audioRecorder.stopRecording() }) {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .font(DesignTokens.Typography.body)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.backgroundSecondaryLight)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

struct SessionCard: View {
    let session: Session
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Session")
                .font(DesignTokens.Typography.title2)
                .foregroundColor(DesignTokens.Colors.textPrimary(for: colorScheme))
            
            Text(session.startTime.formatted())
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary(for: colorScheme))
            
            Text(session.formattedDuration)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.backgroundSecondaryLight)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}
```

---

## ✅ TESTING CHECKLIST

### Phase 1 MVP Tests

- [ ] **Audio recording starts when "New Session" tapped**
- [ ] **Recording continues when app backgrounded**
- [ ] **Recording continues when phone locked**
- [ ] **Session appears in list after stopping**
- [ ] **Timer updates every second**
- [ ] **Sessions persist after app restart**
- [ ] **Dark mode switches correctly**

---

## 🎯 CLAUDE CODE BEST PRACTICES

### How to Prompt Effectively

**Good prompts:**
```
"Create the AudioRecorder service following the technical spec. Include background recording support and proper error handling."

"Build the HomeView with session list, following the UI spec. Use DesignTokens for colors and spacing."

"Add WhisperKit integration to TranscriptionEngine. Process 30-second audio chunks and save segments to database."
```

**When stuck:**
```
"The audio recording stops when the app is backgrounded. Debug this using AVAudioSession background modes."

"WhisperKit model download is failing. Add error handling and retry logic."
```

---

## 🔌 MCP SERVERS

**Currently using:**
- `context7` ✅ (Context maintenance)

**Recommended additions:**
- `filesystem` - Read/write project files efficiently
- `sequential-thinking` - Debug complex issues step-by-step

---

## 📚 RESOURCES

**Documentation:**
- WhisperKit: https://github.com/argmaxinc/WhisperKit
- AVFoundation: https://developer.apple.com/av-foundation/
- SwiftUI: https://developer.apple.com/documentation/swiftui/

**When you get errors:**
1. Check Info.plist permissions
2. Verify background modes enabled
3. Test on physical device (not simulator for audio)

---

**You're ready to build! Start with Step 1 and work sequentially. Reference the technical and UI specs as needed.**
