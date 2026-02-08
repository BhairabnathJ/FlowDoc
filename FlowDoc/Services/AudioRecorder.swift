import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentSession: Session?
    @Published var duration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var durationTimer: Timer?
    private var chunkTimer: Timer?

    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?

    private var lastChunkOffset: TimeInterval = 0
    private let chunkInterval: TimeInterval = 30.0 // Send chunk every 30 seconds

    // Background task support
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // Kill switch
    private let killSwitch = KillSwitchDetector()

    override init() {
        super.init()
        setupAudioSession()
        setupInterruptionHandling()
        killSwitch.onTrigger = { [weak self] in
            Task { @MainActor [weak self] in
                self?.stopRecording()
            }
        }
    }

    private func setupAudioSession() {
        #if !targetEnvironment(macCatalyst)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            print("✅ AudioRecorder: Audio session configured")
        } catch {
            print("❌ AudioRecorder: Failed to set up audio session: \(error)")
        }
        #else
        print("ℹ️ AudioRecorder: AVAudioSession not available on Mac Catalyst")
        #endif
    }

    // MARK: - Interruption Handling

    private func setupInterruptionHandling() {
        #if !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        #endif
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("⏸️ AudioRecorder: Interruption began (phone call)")
            if isRecording && !isPaused {
                pauseRecording()
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("▶️ AudioRecorder: Resuming after interruption")
                    resumeRecording()
                }
            }
        @unknown default:
            break
        }
    }

    // MARK: - Background Task

    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "FlowDocRecording") { [weak self] in
            Task { @MainActor [weak self] in
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - Session State Persistence

    func saveCurrentSessionState() {
        guard isRecording, var session = currentSession else { return }
        session.endTime = Date()
        DatabaseManager.shared.saveSession(session)
        print("✅ AudioRecorder: Saved session state")
    }

    func startRecording() {
        guard !isRecording else {
            print("⚠️ AudioRecorder: Already recording")
            return
        }

        let session = Session()
        currentSession = session

        let audioURL = documentDirectory().appendingPathComponent("\(session.id.uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000, // WhisperKit expects 16kHz
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            // Begin background task so recording continues when app backgrounds
            beginBackgroundTask()

            // Start kill switch detection
            killSwitch.start()

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isRecording = true
                self.isPaused = false
                self.recordingStartTime = Date()
                self.duration = 0
                self.pausedDuration = 0
                self.lastChunkOffset = 0
            }

            // Save session to DB
            DatabaseManager.shared.saveSession(session)

            // Start transcription
            Task {
                TranscriptionEngine.shared.start(sessionID: session.id)
            }

            // Start duration timer (UI updates)
            durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateDuration()
                }
            }

            // Start chunk processing timer
            chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkInterval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.processAudioChunk()
                }
            }

            print("✅ AudioRecorder: Recording started for session \(session.id)")
        } catch {
            print("❌ AudioRecorder: Failed to start recording: \(error)")
        }
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }

        audioRecorder?.pause()
        TranscriptionEngine.shared.pause()

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isPaused = true
            self.pauseStartTime = Date()
        }

        print("⏸️ AudioRecorder: Recording paused")
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }

        audioRecorder?.record()
        TranscriptionEngine.shared.resume()

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isPaused = false

            if let pauseStart = self.pauseStartTime {
                self.pausedDuration += Date().timeIntervalSince(pauseStart)
                self.pauseStartTime = nil
            }
        }

        print("▶️ AudioRecorder: Recording resumed")
    }

    func stopRecording() {
        guard isRecording else { return }

        audioRecorder?.stop()
        durationTimer?.invalidate()
        chunkTimer?.invalidate()
        durationTimer = nil
        chunkTimer = nil

        // Stop kill switch detection
        killSwitch.stop()

        // End background task
        endBackgroundTask()

        // Process final chunk if any remaining audio
        Task {
            await processAudioChunk()

            // Stop transcription (will save final segments to DB)
            TranscriptionEngine.shared.stop()

            // Update session with final metadata
            if var session = currentSession {
                session.endTime = Date()
                DatabaseManager.shared.saveSession(session)
                print("✅ AudioRecorder: Session \(session.id) saved with duration \(session.duration)s")
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isRecording = false
                self.isPaused = false
                self.recordingStartTime = nil
                self.pausedDuration = 0
                self.lastChunkOffset = 0
            }
        }

        print("⏹️ AudioRecorder: Recording stopped")
    }

    private func updateDuration() {
        guard let startTime = recordingStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime) - pausedDuration

        // Don't update duration while paused
        guard !isPaused else { return }

        // Wrap @Published update in Task to defer to next run loop iteration
        // This prevents "Publishing changes from within view updates" error
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.duration = elapsed
        }
    }

    private func processAudioChunk() async {
        guard isRecording, currentSession != nil, let audioURL = audioRecorder?.url else {
            return
        }

        // Don't process chunks while paused
        guard !isPaused else { return }

        // Get current recording duration (actual audio time, not wall time)
        let currentOffset = audioRecorder?.currentTime ?? 0

        // Only process if we have new audio (at least 10 seconds)
        guard currentOffset - lastChunkOffset >= 10.0 else {
            return
        }

        print("🎤 AudioRecorder: Processing audio chunk at offset \(currentOffset)s")

        // Send chunk to transcription engine
        await TranscriptionEngine.shared.processChunk(url: audioURL, offsetSeconds: lastChunkOffset)

        lastChunkOffset = currentOffset
    }

    private func documentDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if flag {
                print("✅ AudioRecorder: Recording finished successfully")
            } else {
                print("❌ AudioRecorder: Recording finished with error")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            print("❌ AudioRecorder: Encoding error: \(error?.localizedDescription ?? "unknown")")
        }
    }
}
