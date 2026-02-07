import Foundation
import Vision
import CoreImage
import AVFoundation
import Combine

/// Processes camera frames using Apple Vision framework for contour detection and text recognition.
class CircuitVisionService: ObservableObject {
    @Published private(set) var contourPaths: [CGPath] = []
    @Published private(set) var recognizedTexts: [RecognizedLabel] = []
    @Published private(set) var isProcessing = false

    /// Throttle: skip frames if we're already processing
    private var processingFrame = false
    private var frameCount = 0

    struct RecognizedLabel: Identifiable {
        let id = UUID()
        let text: String
        let boundingBox: CGRect  // normalized 0..1, Vision coordinate system (origin bottom-left)
        let confidence: Float
    }

    // MARK: - Frame Processing

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        // Process every 3rd frame to reduce CPU load
        frameCount += 1
        guard frameCount % 3 == 0 else { return }
        guard !processingFrame else { return }
        processingFrame = true

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            processingFrame = false
            return
        }

        let contourRequest = VNDetectContoursRequest()
        contourRequest.contrastAdjustment = 1.5
        contourRequest.detectsDarkOnLight = true

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .fast
        textRequest.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { self?.processingFrame = false }

            do {
                try handler.perform([contourRequest, textRequest])
            } catch {
                return
            }

            var paths: [CGPath] = []
            var labels: [RecognizedLabel] = []

            // Extract contours
            if let contourResults = contourRequest.results {
                for observation in contourResults {
                    // Get the top-level contour and its children
                    let topContour = observation.topLevelContours
                    for contour in topContour {
                        paths.append(contour.normalizedPath)
                        // Also add child contours for inner details
                        for child in contour.childContours {
                            paths.append(child.normalizedPath)
                        }
                    }
                }
            }

            // Extract text
            if let textResults = textRequest.results {
                for observation in textResults {
                    guard let candidate = observation.topCandidates(1).first,
                          candidate.confidence > 0.5 else { continue }
                    labels.append(RecognizedLabel(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    ))
                }
            }

            Task { @MainActor [weak self] in
                self?.contourPaths = paths
                self?.recognizedTexts = labels
            }
        }
    }

    func reset() {
        contourPaths = []
        recognizedTexts = []
        frameCount = 0
    }
}
