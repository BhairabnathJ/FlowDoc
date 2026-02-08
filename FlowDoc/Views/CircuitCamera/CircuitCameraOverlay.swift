import SwiftUI
import Vision

/// AR-style overlay that renders Vision framework contours and text labels on the camera preview.
struct CircuitCameraOverlay: View {
    let contourPaths: [CGPath]
    let recognizedTexts: [CircuitVisionService.RecognizedLabel]
    let viewSize: CGSize

    var body: some View {
        ZStack {
            // Contour paths
            ForEach(Array(contourPaths.prefix(50).enumerated()), id: \.offset) { _, path in
                ContourShape(normalizedPath: path)
                    .stroke(Color.cyan.opacity(0.7), lineWidth: 1.5)
            }

            // Text labels
            ForEach(recognizedTexts.prefix(10)) { label in
                let rect = visionRectToView(label.boundingBox)
                TextLabelView(text: label.text, confidence: label.confidence)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
    }

    /// Convert Vision's normalized rect (origin bottom-left) to SwiftUI view coordinates (origin top-left).
    private func visionRectToView(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x * viewSize.width,
            y: (1 - rect.origin.y - rect.height) * viewSize.height,
            width: rect.width * viewSize.width,
            height: rect.height * viewSize.height
        )
    }
}

/// Renders a Vision normalized CGPath scaled to the view.
struct ContourShape: Shape {
    let normalizedPath: CGPath

    func path(in rect: CGRect) -> Path {
        var transform = CGAffineTransform.identity
            .scaledBy(x: rect.width, y: -rect.height)
            .translatedBy(x: 0, y: -1)

        guard let scaled = normalizedPath.copy(using: &transform) else {
            return Path()
        }
        return Path(scaled)
    }
}

/// Floating label for recognized text.
struct TextLabelView: View {
    let text: String
    let confidence: Float

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
    }
}
