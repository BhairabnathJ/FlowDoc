import Foundation
import AVFoundation

/// Detects the volume-down ×3 hardware gesture and fires `onTrigger`.
///
/// Voice-phrase detection is deferred until WhisperKit replaces AVAudioRecorder
/// with AVAudioEngine (the two cannot share the mic input simultaneously).
class KillSwitchDetector: NSObject {

    /// Called on the main thread when the gesture fires.
    var onTrigger: (() -> Void)?

    private var previousVolume: Float = 0
    private var pressCount      = 0
    private var pressTimer:     Timer?
    /// Window in which 3 down-presses must occur to qualify as a gesture.
    private let pressWindow:    TimeInterval = 1.5

    override init() {
        previousVolume = AVAudioSession.sharedInstance().outputVolume
        super.init()
    }

    // MARK: – Lifecycle

    func start() {
        startVoicePhraseDetectionIfPossible()
        AVAudioSession.sharedInstance().addObserver(
            self, forKeyPath: "outputVolume", options: [], context: nil
        )
        print("KillSwitchDetector started (volume-down ×3)")
    }

    func stop() {
        AVAudioSession.sharedInstance().removeObserver(
            self, forKeyPath: "outputVolume"
        )
        pressTimer?.invalidate()
        pressTimer = nil
        pressCount = 0
    }

    // MARK: – Voice phrase (stub)

    /// Placeholder for voice-phrase kill switch detection.
    func startVoicePhraseDetectionIfPossible() {
        // TODO: When AudioRecorder migrates to AVAudioEngine, share buffers
        // with SFSpeechRecognizer or reuse WhisperKit transcript to detect
        // the custom kill phrase ("BIG APPLE BAZINGA").
    }

    // MARK: – KVO

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard keyPath == "outputVolume" else { return }
        let current = AVAudioSession.sharedInstance().outputVolume
        defer { previousVolume = current }
        guard current < previousVolume else { return }   // only down-presses count

        pressCount += 1
        if pressCount == 1 {
            pressTimer = Timer.scheduledTimer(
                withTimeInterval: pressWindow, repeats: false
            ) { [weak self] _ in
                self?.pressCount = 0
            }
        }
        if pressCount >= 3 {
            pressTimer?.invalidate()
            pressTimer = nil
            pressCount = 0
            print("Kill-switch gesture detected (volume-down ×3)")
            onTrigger?()
        }
    }
}
