import SwiftUI

/// A single timestamped line in the live or historical transcript.
struct TranscriptRow: View {
    let segment: Segment
    @Environment(\.colorScheme) var colorScheme

    private var isPauseMarker: Bool {
        segment.text.hasPrefix("[Recording paused")
    }

    var body: some View {
        if isPauseMarker {
            pauseMarkerView
        } else {
            normalView
        }
    }

    // MARK: - Normal speech segment

    private var normalView: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
            Text(segment.formattedTimestamp)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.accentPrimary(for: colorScheme))
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                if let speaker = segment.speakerID {
                    Text("Speaker \(speaker)")
                        .font(DesignTokens.Typography.tiny)
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                }
                Text(segment.text)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    // MARK: - Pause marker

    private var pauseMarkerView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "pause.circle")
                .font(.system(size: 14))
            Text("\(segment.text) — \(segment.formattedTimestamp)")
                .font(DesignTokens.Typography.small.italic())
        }
        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}
