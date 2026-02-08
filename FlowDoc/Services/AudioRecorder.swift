import Foundation
import Combine
import AVFoundation

// MARK: - Recording state

/// Lifecycle state of an audio-recording session.
enum RecordingState: Equatable {
    case idle       /// No session in progress.
    case recording  /// Mic is active; audio is being written to disk.
    case paused     /// Session exists but mic is muted; nothing is saved during the pause.
}

// MARK: - AudioRecorder

/// Observable model that owns the AVAudioRecorder and publishes state for SwiftUI.
/// Background audio mode (declared in Info.plist) keeps recording alive when the
/// app is backgrounded or the screen locks.
///
/// Every 30 seconds a parallel chunk recorder captures audio and feeds it to
/// `TranscriptionEngine` for on-device WhisperKit transcription.
class AudioRecorder: ObservableObject {
    @Published private(set) var state:          RecordingState = .idle
    @Published private(set) var currentSession: Session?
    /// Pause-aware elapsed seconds; ticks every second while recording.
    @Published private(set) var elapsedTime:    TimeInterval   = 0

    private var recorder:        AVAudioRecorder?
    private var timer:           Timer?
    /// Wall-clock start of the current continuous recording segment.
    private var segmentStart:    Date?
    /// Accumulated seconds from segments before the most recent pause.
    private var accumulatedTime: TimeInterval = 0

    // MARK: - Transcription chunking

    private let transcriptionEngine = TranscriptionEngine.shared
    /// Duration of each audio chunk sent to the transcription engine.
    private let chunkDuration: TimeInterval = 30.0
    private var chunkTimer:    Timer?
    private var chunkRecorder: AVAudioRecorder?
    private var chunkIndex     = 0
    /// Wall-clock time at which the current session started recording.
    private var sessionStartDate: Date?

    // TODO: Switch to Linear PCM for better Whisper compatibility and to avoid
    // AAC decode overhead. Spec recommends:
    //   AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000,
    //   AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false
    private let chunkSettings: [String: Any] = [
        AVFormatIDKey:            Int(kAudioFormatLinearPCM),
        AVSampleRateKey:          16_000,
        AVNumberOfChannelsKey:    1,
        AVLinearPCMBitDepthKey:   16,
        AVLinearPCMIsFloatKey:    false
    ]

    // MARK: - Read-only helpers

    var hasActiveSession: Bool { currentSession != nil }

    var formattedElapsedTime: String {
        Session.formatDuration(elapsedTime)
    }

    // MARK: - Controls

    /// Entry-point from the UI.  Non-async so it can be wired directly to a button action.
    func startRecording() {
        Task { await performStart() }
    }

    func pauseRecording() {
        guard state == .recording else { return }
        recorder?.pause()
        if let start = segmentStart {
            accumulatedTime += Date().timeIntervalSince(start)
            segmentStart = nil
        }
        state = .paused
        stopTimer()

        // Flush the current chunk and pause chunk recording
        flushCurrentChunk()
        stopChunkTimer()

        // Insert a pause marker into the transcript
        transcriptionEngine.insertPauseMarker(at: elapsedTime)

        print("Recording paused at \(formattedElapsedTime)")
    }

    func resumeRecording() {
        guard state == .paused else { return }
        recorder?.record()
        segmentStart = Date()
        state = .recording
        startTimer()
        startChunkTimer()
        print("Recording resumed")
    }

    func stopRecording() {
        // Flush last chunk before tearing down
        flushCurrentChunk()
        stopChunkTimer()

        recorder?.stop()
        stopTimer()

        transcriptionEngine.stop()

        if var session = currentSession {
            session.endTime = Date()
            DatabaseManager.shared.updateSession(session)
            print("Session ended: \(session.id)  duration: \(session.formattedDuration)")
        }

        recorder          = nil
        currentSession    = nil
        state             = .idle
        elapsedTime       = 0
        accumulatedTime   = 0
        segmentStart      = nil
        sessionStartDate  = nil
        chunkIndex        = 0
    }

    // MARK: - Private – start flow

    private func performStart() async {
        // Request mic permission via the iOS 17+ API.
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission(completionHandler: { result in
                cont.resume(returning: result)
            })
        }
        guard granted else {
            print("Microphone permission denied")
            return
        }

        // Configure AVAudioSession for background recording.
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default, options: [.allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            print("AVAudioSession configuration error: \(error)")
            return
        }

        // Persist new session.
        let session = Session()
        currentSession = session
        DatabaseManager.shared.saveSession(session)

        // Open the main recorder on disk (full session archive in AAC).
        let filePath = documentsDirectory.appendingPathComponent("\(session.id).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey:            Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:          16_000,
            AVNumberOfChannelsKey:    1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: filePath, settings: settings)
            recorder?.record()

            state             = .recording
            segmentStart      = Date()
            sessionStartDate  = Date()
            accumulatedTime   = 0
            elapsedTime       = 0
            chunkIndex        = 0
            startTimer()

            // Start transcription session and chunk timer
            transcriptionEngine.start(sessionID: session.id)
            startChunkRecorder()
            startChunkTimer()

            print("Recording started → \(filePath.lastPathComponent)")
        } catch {
            print("AVAudioRecorder creation error: \(error)")
            currentSession = nil
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let start = segmentStart else { return }
        elapsedTime = accumulatedTime + Date().timeIntervalSince(start)
    }

    // MARK: - Chunk recording

    private func startChunkTimer() {
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.rotateChunk()
            }
        }
    }

    private func stopChunkTimer() {
        chunkTimer?.invalidate()
        chunkTimer = nil
    }

    /// Rotate: stop current chunk recorder, feed it to transcription, start a new one.
    private func rotateChunk() {
        flushCurrentChunk()
        startChunkRecorder()
    }

    /// Stop the current chunk recorder and send the file to TranscriptionEngine.
    private func flushCurrentChunk() {
        guard let cr = chunkRecorder else { return }
        let url = cr.url
        let offset = Double(chunkIndex) * chunkDuration
        cr.stop()
        chunkRecorder = nil
        chunkIndex += 1

        Task.detached {
            await TranscriptionEngine.shared.processChunk(url: url, offsetSeconds: offset)
            // Clean up temporary chunk file
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Start a new parallel chunk recorder writing Linear PCM for Whisper.
    private func startChunkRecorder() {
        guard state == .recording else { return }
        let chunkURL = chunksDirectory.appendingPathComponent("chunk_\(chunkIndex).wav")
        do {
            chunkRecorder = try AVAudioRecorder(url: chunkURL, settings: chunkSettings)
            chunkRecorder?.record()
        } catch {
            print("Chunk recorder error: \(error)")
        }
    }

    // MARK: - Helpers

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var chunksDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("chunks", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
