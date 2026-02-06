import SwiftUI

/// A single timestamped line in the live or historical transcript.
struct TranscriptRow: View {
    let segment: Segment
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
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
}
