import Foundation
import Combine

/// On-device transcription via WhisperKit.
///
/// **Setup required:** Add WhisperKit as an SPM dependency in Xcode
///   File → Add Packages → https://github.com/argmaxinc/WhisperKit.git  (≥ 0.15.0)
///
/// Until the package is linked this class compiles and runs but produces no
/// segments.  The rest of the recording pipeline works independently.
class TranscriptionEngine: ObservableObject {
    static let shared = TranscriptionEngine()

    @Published private(set) var segments: [Segment] = []

    private var sessionID: UUID?

    private init() {
        print("TranscriptionEngine: initialised (WhisperKit not yet linked)")
    }

    /// Begin a new transcription session.
    func start(sessionID: UUID) {
        self.sessionID = sessionID
        self.segments  = []
        print("TranscriptionEngine: start() – session \(sessionID)")
    }

    /// End the current transcription session.
    func stop() {
        print("TranscriptionEngine: stop() – \(segments.count) segment(s)")
        sessionID = nil
    }

    /// Feed a completed audio chunk.  No-op until WhisperKit is linked.
    func processChunk(url: URL, offsetSeconds: TimeInterval) async {
        // WhisperKit integration point:
        //   let results = try await whisperKit?.transcribe(audioPath: url.path)
        //   for seg in results.segments { … append … }
    }
}
