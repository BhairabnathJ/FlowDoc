import SwiftUI

struct HomeView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @State          private var sessions:  [Session] = []
    @Environment(\.colorScheme) var colorScheme

    /// Past sessions excluding whichever session is currently active.
    private var pastSessions: [Session] {
        sessions.filter { $0.id != audioRecorder.currentSession?.id }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {

                        // --- active-session card ---
                        if audioRecorder.hasActiveSession {
                            ActiveSessionCard(audioRecorder: audioRecorder)
                                .padding(.horizontal, DesignTokens.Spacing.lg)
                                .padding(.top,        DesignTokens.Spacing.lg)
                        }

                        // --- session list  OR  empty state ---
                        if !pastSessions.isEmpty {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                Text("Recent Sessions")
                                    .font(DesignTokens.Typography.title2)
                                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                                    .padding(.horizontal, DesignTokens.Spacing.lg)
                                    .padding(.top, audioRecorder.hasActiveSession
                                        ? DesignTokens.Spacing.md
                                        : DesignTokens.Spacing.lg)

                                ForEach(pastSessions) { session in
                                    SessionCard(session: session)
                                        .padding(.horizontal, DesignTokens.Spacing.lg)
                                }
                            }
                        } else if !audioRecorder.hasActiveSession {
                            emptyState
                        }
                    }
                    .padding(.bottom, 100) // room for FAB
                }

                // --- FAB (hidden while a session is active) ---
                if !audioRecorder.hasActiveSession {
                    fab
                }
            }
            .background(DesignTokens.Colors.backgroundPrimary(for: colorScheme))
            .navigationTitle("FlowDoc")
            .toolbarBackground(
                DesignTokens.Colors.backgroundPrimary(for: colorScheme),
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                    }
                }
            }
        }
        .onAppear  { loadSessions() }
        .onChange(of: audioRecorder.state) { _, newState in
            if newState == .idle { loadSessions() }
        }
    }

    // MARK: - FAB

    private var fab: some View {
        Button(action: { audioRecorder.startRecording() }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("New Session")
                    .font(DesignTokens.Typography.bodyMedium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical,   DesignTokens.Spacing.lg)
            .background(DesignTokens.Colors.accentPrimary(for: colorScheme))
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .padding(.bottom, DesignTokens.Spacing.xl)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "mic.circle")
                .font(.system(size: 56))
                .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
            Text("No sessions yet")
                .font(DesignTokens.Typography.title2)
                .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
            Text("Tap \"New Session\" to start recording")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(.top,        100)
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }

    // MARK: - Data

    private func loadSessions() {
        sessions = DatabaseManager.shared.fetchAllSessions()
    }
}

// MARK: - ActiveSessionCard

/// Card shown while a session is in progress.  Displays the live timer and
/// pause / stop controls.  Updates automatically as AudioRecorder publishes changes.
struct ActiveSessionCard: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {

            // State label row
            HStack(spacing: DesignTokens.Spacing.sm) {
                statusIndicator
                Text(audioRecorder.state == .recording ? "Recording" : "Paused")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundStyle(labelColor)
            }

            // Live timer
            Text(audioRecorder.formattedElapsedTime)
                .font(DesignTokens.Typography.display)
                .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                .monospacedDigit()

            // Controls
            HStack(spacing: DesignTokens.Spacing.md) {
                pauseResumeButton
                stopButton
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.backgroundSecondary(for: colorScheme))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(borderColor.opacity(0.3), lineWidth: 1.5)
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var statusIndicator: some View {
        if audioRecorder.state == .recording {
            RecordingDot()
        } else {
            Circle()
                .fill(DesignTokens.Colors.statePaused(for: colorScheme))
                .frame(width: 12, height: 12)
        }
    }

    private var pauseResumeButton: some View {
        Button(action: togglePause) {
            Label(
                audioRecorder.state == .recording ? "Pause"  : "Resume",
                systemImage: audioRecorder.state == .recording ? "pause.circle.fill" : "play.circle.fill"
            )
            .labelStyle(.iconOnly)
            .font(.title2)
            .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
        }
    }

    private var stopButton: some View {
        Button(action: { audioRecorder.stopRecording() }) {
            Label("Stop", systemImage: "stop.circle.fill")
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(DesignTokens.Colors.stateRecording(for: colorScheme))
        }
    }

    // MARK: - Helpers

    private var labelColor: Color {
        audioRecorder.state == .recording
            ? DesignTokens.Colors.stateRecording(for: colorScheme)
            : DesignTokens.Colors.statePaused(for: colorScheme)
    }

    private var borderColor: Color { labelColor }

    private func togglePause() {
        if audioRecorder.state == .recording {
            audioRecorder.pauseRecording()
        } else {
            audioRecorder.resumeRecording()
        }
    }
}
