import SwiftUI

/// Small accent-coloured label used for session tags.
struct TagView: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(text)
            .font(DesignTokens.Typography.tiny)
            .foregroundStyle(DesignTokens.Colors.accentPrimary(for: colorScheme))
            .padding(.horizontal, 8)
            .padding(.vertical,   4)
            .background(DesignTokens.Colors.accentPrimary(for: colorScheme).opacity(0.12))
            .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}
