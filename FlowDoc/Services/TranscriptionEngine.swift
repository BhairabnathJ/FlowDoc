import Foundation
import Combine
import AVFoundation
import Speech

/// On-device transcription using Apple Speech framework (SFSpeechRecognizer).
/// Falls back to stub mode if speech recognition is unavailable or denied.
@MainActor
class TranscriptionEngine: ObservableObject {
    static let shared = TranscriptionEngine()

    @Published private(set) var segments: [Segment] = []
    @Published private(set) var isModelLoaded: Bool = false
    @Published private(set) var liveText: String = ""
    @Published private(set) var lastError: String?

    private nonisolated(unsafe) var speechRecognizer: SFSpeechRecognizer?
    private nonisolated(unsafe) var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private nonisolated(unsafe) var recognitionTask: SFSpeechRecognitionTask?
    private nonisolated(unsafe) var audioEngine: AVAudioEngine?

    private var sessionID: UUID?
    private var sessionStartTime: Date?
    private var lastSegmentEndTime: TimeInterval = 0
    private var lastCommittedText: String = ""
    private var usingSpeechFramework: Bool = false

    // Stub fallback
    private var stubTimer: Timer?
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
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        // Request authorization upfront so it's ready when recording starts
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                self.isModelLoaded = true
                if status == .authorized {
                    self.usingSpeechFramework = true
                    print("TranscriptionEngine: Speech recognition authorized (on-device)")
                } else {
                    self.usingSpeechFramework = false
                    print("TranscriptionEngine: Speech not authorized (\(status.rawValue)), using stub mode")
                }
            }
        }
    }

    // MARK: - Public API

    /// Check auth status synchronously to avoid race with async requestAuthorization
    private func isSpeechAvailable() -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        return status == .authorized && speechRecognizer?.isAvailable == true
    }

    func start(sessionID: UUID) {
        self.sessionID = sessionID
        self.segments = []
        self.liveText = ""
        self.lastCommittedText = ""
        self.lastSegmentEndTime = 0
        self.stubIndex = 0
        self.sessionStartTime = Date()

        // Check auth status synchronously — don't rely on the async callback flag
        let speechAvailable = isSpeechAvailable()
        usingSpeechFramework = speechAvailable
        print("TranscriptionEngine: Started session \(sessionID) [speech=\(speechAvailable)]")

        if speechAvailable {
            startLiveRecognition()
        } else {
            startStubTimer()
        }
    }

    func stop() {
        if usingSpeechFramework {
            stopLiveRecognition()
        } else {
            stopStubTimer()
        }

        // Save segments to database
        if let sessionID = sessionID {
            let segmentsToSave = self.segments
            for segment in segmentsToSave {
                DatabaseManager.shared.saveSegment(segment, transcriptId: sessionID)
            }
            print("TranscriptionEngine: Saved \(segmentsToSave.count) segments to DB")
        }

        sessionID = nil
        sessionStartTime = nil
        liveText = ""
        print("TranscriptionEngine: Stopped - \(segments.count) segment(s)")
    }

    func pause() {
        if usingSpeechFramework {
            stopLiveRecognition()
        } else {
            stopStubTimer()
        }
    }

    func resume() {
        if usingSpeechFramework {
            startLiveRecognition()
        } else {
            startStubTimer()
        }
    }

    func processChunk(url: URL, offsetSeconds: TimeInterval) async {
        // Not needed when using live recognition
    }

    // MARK: - Live Speech Recognition

    private func startLiveRecognition() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("TranscriptionEngine: Speech recognizer not available")
            lastError = "Speech recognition unavailable"
            return
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        let engine = AVAudioEngine()
        self.audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.recognitionRequest = request

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
            print("TranscriptionEngine: Audio engine started for live recognition")
        } catch {
            print("TranscriptionEngine: Audio engine failed: \(error)")
            lastError = "Audio engine error"
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { @Sendable result, error in
            let isFinal = result?.isFinal ?? false
            let fullText = result?.bestTranscription.formattedString
            let errorCode = (error as? NSError)?.code

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let fullText = fullText {
                    self.liveText = fullText

                    if isFinal {
                        self.commitSegment(text: fullText)
                        self.restartRecognition()
                    } else {
                        self.checkForNewSegments(fullText: fullText)
                    }
                }

                if error != nil, errorCode != 1, errorCode != 216 {
                    print("TranscriptionEngine: Recognition error code \(errorCode ?? -1)")
                    self.restartRecognition()
                }
            }
        }
    }

    private func stopLiveRecognition() {
        // Commit any remaining text
        if !liveText.isEmpty && liveText != lastCommittedText {
            let uncommitted = getUncommittedText(from: liveText)
            if !uncommitted.isEmpty {
                commitSegment(text: uncommitted)
            }
        }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func restartRecognition() {
        guard sessionID != nil else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        lastCommittedText = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startLiveRecognition()
        }
    }

    // MARK: - Segment Management

    private func checkForNewSegments(fullText: String) {
        let uncommitted = getUncommittedText(from: fullText)
        guard !uncommitted.isEmpty else { return }

        var textToCommit: String?

        // Check for sentence-ending punctuation
        let sentenceEnders: [Character] = [".", "!", "?"]
        if let lastEnderIndex = uncommitted.lastIndex(where: { sentenceEnders.contains($0) }) {
            textToCommit = String(uncommitted[uncommitted.startIndex...lastEnderIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Also commit if we have enough words (handles unpunctuated speech)
        else {
            let wordCount = uncommitted.split(separator: " ").count
            if wordCount >= 6 {
                textToCommit = uncommitted.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let text = textToCommit, !text.isEmpty {
            commitSegment(text: text)
            let consumed = lastCommittedText + (lastCommittedText.isEmpty ? "" : " ") + text
            lastCommittedText = consumed
        }
    }

    private func getUncommittedText(from fullText: String) -> String {
        if lastCommittedText.isEmpty { return fullText }
        if fullText.hasPrefix(lastCommittedText) {
            let startIndex = fullText.index(fullText.startIndex, offsetBy: lastCommittedText.count)
            return String(fullText[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return fullText
    }

    private func commitSegment(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let startTime = sessionStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)

        let segment = Segment(
            text: trimmed,
            startTime: lastSegmentEndTime,
            endTime: elapsed
        )

        segments.append(segment)
        lastSegmentEndTime = elapsed
        print("TranscriptionEngine: Segment: \"\(trimmed.prefix(50))\"")
    }

    // MARK: - Stub Fallback

    private func startStubTimer() {
        stopStubTimer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.generateStubSegment()
        }

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
        guard sessionID != nil, let startTime = sessionStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let text = stubPhrases[stubIndex % stubPhrases.count]

        let segment = Segment(
            text: text,
            startTime: max(0, elapsed - 5.0),
            endTime: elapsed
        )

        segments.append(segment)
        stubIndex += 1
        print("TranscriptionEngine [STUB]: \"\(text.prefix(40))...\"")
    }
}
