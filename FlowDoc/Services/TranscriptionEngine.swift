import Foundation
import Combine
import WhisperKit

/// On-device transcription via WhisperKit.
///
/// Uses the `base.en` model with CPU + Neural Engine for low-latency,
/// privacy-first transcription. Audio chunks (typically 30 s) are fed in
/// via `processChunk(url:offsetSeconds:)` and results are published to
/// `segments` for the UI to observe.
class TranscriptionEngine: ObservableObject {
    static let shared = TranscriptionEngine()

    // MARK: - Published state

    @Published private(set) var segments: [Segment] = []
    @Published private(set) var modelDownloadProgress: Double?
    @Published private(set) var isModelReady = false

    // MARK: - Private

    private var whisperKit: WhisperKit?
    private var isInitializing = false
    private var currentSessionID: UUID?

    private init() {
        print("TranscriptionEngine: initialised")
    }

    // MARK: - Model lifecycle

    /// Lazily downloads and loads the WhisperKit model on first use.
    func initializeIfNeeded() async throws {
        if isModelReady { return }
        guard !isInitializing else { return }
        isInitializing = true

        await MainActor.run {
            self.modelDownloadProgress = 0.0
        }

        let config = WhisperKitConfig(
            model: "base.en",
            verbose: false
        )
        let kit = try await WhisperKit(config)

        await MainActor.run {
            self.whisperKit = kit
            self.isModelReady = true
            self.modelDownloadProgress = nil
            self.isInitializing = false
        }
        print("TranscriptionEngine: WhisperKit model ready")
    }

    // MARK: - Session lifecycle

    /// Begin a new transcription session.
    func start(sessionID: UUID) {
        self.currentSessionID = sessionID
        self.segments = []
        print("TranscriptionEngine: start() – session \(sessionID)")

        // Kick off model init in the background so first chunk is fast
        Task.detached { [weak self] in
            try? await self?.initializeIfNeeded()
        }
    }

    /// End the current transcription session.
    func stop() {
        print("TranscriptionEngine: stop() – \(segments.count) segment(s)")
        currentSessionID = nil
    }

    /// Insert a visible gap marker into the transcript.
    func insertPauseMarker(at offset: TimeInterval) {
        let seg = Segment(
            text: "[Recording paused]",
            startTime: offset,
            endTime: offset,
            confidence: 1.0
        )
        segments.append(seg)
    }

    // MARK: - Chunk processing

    /// Feed a completed audio chunk for transcription.
    ///
    /// - Parameters:
    ///   - url: File URL of the audio chunk (WAV/M4A).
    ///   - offsetSeconds: Time offset of this chunk relative to session start.
    func processChunk(url: URL, offsetSeconds: TimeInterval) async {
        do {
            try await initializeIfNeeded()
        } catch {
            print("TranscriptionEngine: model init failed – \(error)")
            return
        }

        guard let kit = whisperKit else { return }

        do {
            let options = DecodingOptions(
                temperature: 0.0,
                topK: 5,
                usePrefillPrompt: true
            )

            let results = try await kit.transcribe(
                audioPath: url.path,
                decodeOptions: options
            )

            for result in results {
                for wSeg in result.segments {
                    let text = wSeg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }

                    let seg = Segment(
                        text: text,
                        startTime: offsetSeconds + Double(wSeg.start),
                        endTime: offsetSeconds + Double(wSeg.end),
                        confidence: 1.0 - wSeg.noSpeechProb  // higher = more confident
                    )

                    await MainActor.run {
                        self.segments.append(seg)
                    }

                    // TODO: persist via DatabaseManager.saveSegment(seg, transcriptId:)
                    // once transcript-to-session wiring is in place.
                }
            }
        } catch {
            print("TranscriptionEngine: transcription error – \(error)")
        }
    }
}
