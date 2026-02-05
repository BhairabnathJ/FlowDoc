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
        print("Recording paused at \(formattedElapsedTime)")
    }

    func resumeRecording() {
        guard state == .paused else { return }
        recorder?.record()
        segmentStart = Date()
        state = .recording
        startTimer()
        print("Recording resumed")
    }

    func stopRecording() {
        recorder?.stop()
        stopTimer()

        if var session = currentSession {
            session.endTime = Date()
            DatabaseManager.shared.updateSession(session)
            print("Session ended: \(session.id)  duration: \(session.formattedDuration)")
        }

        recorder        = nil
        currentSession  = nil
        state           = .idle
        elapsedTime     = 0
        accumulatedTime = 0
        segmentStart    = nil
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

        // Open the recorder on disk.
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

            state           = .recording
            segmentStart    = Date()
            accumulatedTime = 0
            elapsedTime     = 0
            startTimer()

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

    // MARK: - Helpers

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
