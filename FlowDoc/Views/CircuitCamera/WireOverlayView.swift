import SwiftUI

// MARK: - WireOverlayView

/// Draws detected wire polylines and optional endpoint labels on top of the camera preview.
///
/// Coordinates arrive in Vision normalized space (bottom-left origin, 0...1)
/// and are converted to UIKit view coordinates for rendering via SwiftUI `Canvas`.
///
/// Polylines are colored by tracking confidence:
/// - Green (≥0.7): high confidence
/// - Yellow (0.4–0.7): medium confidence
/// - Red (<0.4): low confidence
///
/// When `mappedConnections` is non-empty (board is calibrated), endpoint labels
/// like "Row 12F" are drawn near wire start/end positions.
struct WireOverlayView: View {

    /// Tracked wires from Agent 2 with stable IDs and contour paths.
    let trackedWires: [TrackedWire]

    /// Mapped connections from Agent 3 with breadboard hole labels (empty if not calibrated).
    let mappedConnections: [MappedConnection]

    /// Size of the enclosing view for coordinate conversion.
    let viewSize: CGSize

    /// Maximum number of wires to render per frame.
    private let wireCap = 50

    var body: some View {
        Canvas { context, size in
            let capped = Array(trackedWires.prefix(wireCap))
            let lookup = buildConnectionLookup()

            for wire in capped {
                let uiPoints = wire.contour.path.map { visionToUIKit($0, in: size) }
                guard uiPoints.count >= 2 else { continue }

                // Build polyline path
                var path = Path()
                path.move(to: uiPoints[0])
                for pt in uiPoints.dropFirst() {
                    path.addLine(to: pt)
                }

                // Stroke with confidence-based color
                let color = confidenceColor(wire.trackingConfidence)
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                // Draw endpoint labels when calibrated
                if let mapped = lookup[wire.id] {
                    drawLabel(
                        context: &context,
                        text: mapped.startNode.label,
                        at: visionToUIKit(mapped.startNode.position, in: size)
                    )
                    drawLabel(
                        context: &context,
                        text: mapped.endNode.label,
                        at: visionToUIKit(mapped.endNode.position, in: size)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Coordinate Conversion

    /// Converts a point from Vision normalized coordinates (bottom-left origin)
    /// to UIKit view coordinates (top-left origin).
    private func visionToUIKit(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: (1.0 - point.y) * size.height)
    }

    // MARK: - Confidence Color

    /// Maps tracking confidence to a display color.
    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.7...: return .green
        case 0.4..<0.7: return .yellow
        default: return .red
        }
    }

    // MARK: - Connection Lookup

    /// Builds a wireID → MappedConnection dictionary for O(1) label lookup.
    private func buildConnectionLookup() -> [UUID: MappedConnection] {
        Dictionary(mappedConnections.map { ($0.wireID, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: - Label Drawing

    /// Draws a text label with a dark background pill at the given position.
    private func drawLabel(context: inout GraphicsContext, text: String, at point: CGPoint) {
        let resolved = context.resolve(
            Text(text)
                .font(DesignTokens.Typography.tiny)
                .foregroundColor(.white)
        )

        let textSize = resolved.measure(in: CGSize(width: 200, height: 40))
        let padding = DesignTokens.Spacing.xs

        // Position label above the point
        let bgRect = CGRect(
            x: point.x - textSize.width / 2 - padding,
            y: point.y - textSize.height - padding * 2,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )

        // Background pill
        let bgPath = Path(roundedRect: bgRect, cornerRadius: DesignTokens.CornerRadius.sm)
        context.fill(bgPath, with: .color(.black.opacity(0.7)))

        // Text centered in pill
        context.draw(resolved, at: CGPoint(x: bgRect.midX, y: bgRect.midY), anchor: .center)
    }
}
