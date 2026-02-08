import SwiftUI

/// A single row in the recent-sessions list.
struct SessionCard: View {
    let session: Session
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {

            // Title + completed badge
            HStack {
                Text("Session")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                Spacer()
                StatusBadge(status: .completed)
            }

            // Date · duration
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(session.startTime.formatted(date: .abbreviated, time: .omitted))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                Text("·")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                Text(session.formattedDuration)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
            }

            // Tags (shown only when present)
            if !session.tags.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(session.tags, id: \.self) { tag in
                        TagView(text: tag)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.backgroundSecondary(for: colorScheme))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(DesignTokens.Colors.borderSecondary(for: colorScheme), lineWidth: 1)
        }
    }
}
