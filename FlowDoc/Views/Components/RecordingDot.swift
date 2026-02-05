import SwiftUI

/// Pulsing red dot that indicates an active recording.
struct RecordingDot: View {
    @State  private var isPulsing  = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Circle()
            .fill(DesignTokens.Colors.stateRecording(for: colorScheme))
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
