import SwiftUI

struct PrimaryButton: View {
    let title:  String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundStyle(DesignTokens.Colors.backgroundPrimaryLight)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(DesignTokens.Colors.accentPrimary(for: colorScheme))
                .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }
}
