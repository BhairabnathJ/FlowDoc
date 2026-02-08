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
/// When WhisperKit is not available, runs in stub mode generating placeholder
/// segments every 8 seconds so the UI flow can be tested end-to-end.
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
    private let modelName = "base.en"

    // Stub mode properties
    private var stubTimer: Timer?
    private var stubStartTime: Date?
    private var stubIndex: Int = 0
    private let stubPhrases: [String] = [
        "Starting the session, let me walk through the current setup.",
        "The main board connects here, and we need to check the voltage regulator.",
        "I'm seeing some noise on the signal line, let me adjust the probe.",
        "Okay, the reading looks stable now at 3.3 volts.",
        "Let's document the pin configuration before we move on.",
        "The thermal readings are within spec, no issues there.",
        "I'll take a photo of the board layout for reference.",
        "Moving on to the next test point, checking continuity.",
        "Good, all connections are solid. No open circuits detected.",
        "Let me note the serial number for this prototype unit."
    ]

    private init() {
        print("TranscriptionEngine: initialised")
        #if canImport(WhisperKit)
        Task {
            await loadModel()
        }
        #else
        // Stub mode: mark as ready immediately
        isModelLoaded = true
        modelLoadProgress = 1.0
        print("TranscriptionEngine: Running in STUB mode (WhisperKit not available)")
        #endif
    }

    #if canImport(WhisperKit)
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
        self.segments = []
        self.stubIndex = 0
        self.stubStartTime = Date()
        print("TranscriptionEngine: Started session \(sessionID)")

        #if !canImport(WhisperKit)
        // Start stub timer to generate segments every 8 seconds
        startStubTimer()
        #endif
    }

    /// End the current transcription session.
    func stop() {
        print("TranscriptionEngine: Stopped session - \(segments.count) segment(s)")

        #if !canImport(WhisperKit)
        stopStubTimer()
        #endif

        // Save segments to database
        if let sessionID = sessionID {
            let segmentsToSave = self.segments
            for segment in segmentsToSave {
                DatabaseManager.shared.saveSegment(segment, transcriptId: sessionID)
            }
            print("TranscriptionEngine: Saved \(segmentsToSave.count) segments to DB")
        }

        sessionID = nil
    }

    /// Pause stub generation (called when recording pauses)
    func pause() {
        #if !canImport(WhisperKit)
        stopStubTimer()
        #endif
    }

    /// Resume stub generation (called when recording resumes)
    func resume() {
        #if !canImport(WhisperKit)
        startStubTimer()
        #endif
    }

    /// Process an audio chunk for transcription (WhisperKit mode)
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
            let result = try await whisperKit.transcribe(audioPath: url.path)

            guard let transcription = result?.text, !transcription.isEmpty else {
                print("TranscriptionEngine: No text detected in chunk")
                return
            }

            let segment = Segment(
                text: transcription.trimmingCharacters(in: .whitespacesAndNewlines),
                startTime: offsetSeconds,
                endTime: offsetSeconds + (result?.timings.totalDecodingTime ?? 5.0)
            )

            segments.append(segment)
            print("TranscriptionEngine: Segment added: \"\(segment.text.prefix(50))...\"")
        } catch {
            print("TranscriptionEngine: Transcription failed - \(error.localizedDescription)")
            lastError = "Transcription failed: \(error.localizedDescription)"
        }
        #else
        // Stub mode: segments generated by timer, no chunk processing needed
        #endif
    }

    // MARK: - Stub Mode

    #if !canImport(WhisperKit)
    private func startStubTimer() {
        stopStubTimer()

        // Generate first segment after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.generateStubSegment()
        }

        // Then every 8 seconds
        stubTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.generateStubSegment()
            }
        }
    }

    private func stopStubTimer() {
        stubTimer?.invalidate()
        stubTimer = nil
    }

    private func generateStubSegment() {
        guard sessionID != nil, let startTime = stubStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let phraseIndex = stubIndex % stubPhrases.count
        let text = stubPhrases[phraseIndex]

        let segment = Segment(
            text: text,
            startTime: max(0, elapsed - 5.0),
            endTime: elapsed
        )

        segments.append(segment)
        stubIndex += 1
        print("TranscriptionEngine [STUB]: Segment \(stubIndex): \"\(text.prefix(40))...\"")
    }
    #endif
}
