import SwiftUI

/// Pill-shaped badge that communicates session state at a glance.
struct StatusBadge: View {
    enum Status {
        case recording, paused, processing, completed
    }

    let status: Status
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical,   6)
        .background(statusColor.opacity(0.15))
        .cornerRadius(999)
    }

    // MARK: - Private

    private var statusColor: Color {
        switch status {
        case .recording:  return DesignTokens.Colors.stateRecording(for: colorScheme)
        case .paused:     return DesignTokens.Colors.statePaused(for: colorScheme)
        case .processing: return DesignTokens.Colors.accentPrimary(for: colorScheme)
        case .completed:  return DesignTokens.Colors.textSecondary(for: colorScheme)
        }
    }

    private var statusText: String {
        switch status {
        case .recording:  return "Recording"
        case .paused:     return "Paused"
        case .processing: return "Processing"
        case .completed:  return "Completed"
        }
    }
}
