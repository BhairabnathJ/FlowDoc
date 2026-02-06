import Foundation
import Combine
#if canImport(WhisperKit)
import WhisperKit
#endif

/// On-device transcription via WhisperKit.
///
/// **Setup required:** Add WhisperKit as an SPM dependency in Xcode
///   File → Add Packages → https://github.com/argmaxinc/WhisperKit.git  (≥ 0.15.0)
///
/// Transcribes audio chunks on-device using Apple's Neural Engine.
/// Model downloads automatically on first run (~200MB for base.en).
@MainActor
class TranscriptionEngine: ObservableObject {
    static let shared = TranscriptionEngine()

    @Published private(set) var segments: [Segment] = []
    @Published private(set) var isModelLoaded: Bool = false
    @Published private(set) var modelLoadProgress: Float = 0.0
    @Published private(set) var lastError: String?

    #if canImport(WhisperKit)
    private var whisperKit: WhisperKit?
    #endif

    private var sessionID: UUID?
    private let modelName = "base.en" // 142MB, good accuracy/speed balance

    private init() {
        print("TranscriptionEngine: initialised")
        #if canImport(WhisperKit)
        Task {
            await loadModel()
        }
        #else
        print("TranscriptionEngine: WhisperKit not available (add SPM package)")
        #endif
    }

    #if canImport(WhisperKit)
    /// Load WhisperKit model (downloads on first run)
    private func loadModel() async {
        do {
            print("TranscriptionEngine: Loading WhisperKit model '\(modelName)'...")

            whisperKit = try await WhisperKit(
                model: modelName,
                computeUnits: .cpuAndNeuralEngine,
                verbose: false
            )

            isModelLoaded = true
            modelLoadProgress = 1.0
            print("TranscriptionEngine: Model loaded successfully")
        } catch {
            print("TranscriptionEngine: Model load failed - \(error.localizedDescription)")
            lastError = "Failed to load transcription model: \(error.localizedDescription)"
            isModelLoaded = false
        }
    }
    #endif

    /// Begin a new transcription session.
    func start(sessionID: UUID) {
        self.sessionID = sessionID
        self.segments  = []
        print("TranscriptionEngine: Started session \(sessionID)")
    }

    /// End the current transcription session.
    func stop() {
        print("TranscriptionEngine: Stopped session - \(segments.count) segment(s)")

        // Save segments to database
        if let sessionID = sessionID {
            Task.detached {
                for segment in self.segments {
                    DatabaseManager.shared.saveSegment(segment, transcriptId: sessionID)
                }
                print("TranscriptionEngine: Saved \(self.segments.count) segments to DB")
            }
        }

        sessionID = nil
    }

    /// Process an audio chunk for transcription
    func processChunk(url: URL, offsetSeconds: TimeInterval) async {
        #if canImport(WhisperKit)
        guard isModelLoaded, let whisperKit = whisperKit else {
            print("TranscriptionEngine: Model not loaded, skipping chunk")
            return
        }

        guard let sessionID = sessionID else {
            print("TranscriptionEngine: No active session, skipping chunk")
            return
        }

        do {
            print("TranscriptionEngine: Transcribing chunk at offset \(offsetSeconds)s...")

            // Transcribe audio file
            let result = try await whisperKit.transcribe(audioPath: url.path)

            // Convert WhisperKit segments to our Segment model
            guard let transcription = result?.text, !transcription.isEmpty else {
                print("TranscriptionEngine: No text detected in chunk")
                return
            }

            // Create segment
            let segment = Segment(
                id: UUID(),
                text: transcription.trimmingCharacters(in: .whitespacesAndNewlines),
                timestamp: Date(),
                startTime: offsetSeconds,
                endTime: offsetSeconds + (result?.timings.totalDecodingTime ?? 0),
                speaker: nil // Future: speaker diarization
            )

            // Add to segments array (async on MainActor)
            segments.append(segment)
            print("TranscriptionEngine: ✓ Segment added: \"\(segment.text.prefix(50))...\"")

        } catch {
            print("TranscriptionEngine: Transcription failed - \(error.localizedDescription)")
            lastError = "Transcription failed: \(error.localizedDescription)"
        }
        #else
        print("TranscriptionEngine: WhisperKit not available - add SPM package to enable transcription")
        #endif
    }
}
