import SwiftUI

struct SecondaryButton: View {
    let title:  String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(DesignTokens.Colors.borderSecondary(for: colorScheme))
                .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .accessibilityLabel(title)
    }
}
