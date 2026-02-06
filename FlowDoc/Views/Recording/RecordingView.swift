import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss)     var dismiss

    /// Live segments – populated once WhisperKit transcription is active.
    @State private var segments: [Segment] = []
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 0) {
            timerSection

            Divider()
                .padding(.horizontal, DesignTokens.Spacing.lg)

            ScrollView {
                ScrollViewReader { proxy in
                    transcriptContent
                        .onChange(of: segments.count) { _, _ in
                            if let lastId = segments.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                }
            }

            controlsBar
        }
        .background(DesignTokens.Colors.backgroundPrimary(for: colorScheme))
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            DesignTokens.Colors.backgroundPrimary(for: colorScheme),
            for: .navigationBar
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sessionMenu
            }
        }
        .onChange(of: audioRecorder.state) { _, newState in
            if newState == .idle { dismiss() }
        }
        .sheet(isPresented: $showCamera) {
            if let sessionID = audioRecorder.currentSession?.id {
                CameraView(sessionID: sessionID)
            }
        }
    }

    // MARK: – Timer

    private var timerSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if audioRecorder.state == .recording { RecordingDot() }
                StatusBadge(status: audioRecorder.state == .recording ? .recording : .paused)
            }

            Text(audioRecorder.formattedElapsedTime)
                .font(.system(size: 52, weight: .semibold).monospacedDigit())
                .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xl)
    }

    // MARK: – Transcript

    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Live Transcript")
                .font(DesignTokens.Typography.title2)
                .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))

            if segments.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                    Text("Transcription will appear here")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                    Text("Add WhisperKit via SPM to enable live transcription")
                        .font(DesignTokens.Typography.small)
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DesignTokens.Spacing.xl)
            } else {
                ForEach(segments) { segment in
                    TranscriptRow(segment: segment)
                        .id(segment.id)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top,        DesignTokens.Spacing.lg)
        .padding(.bottom,     DesignTokens.Spacing.xxl)
    }

    // MARK: – Controls

    private var controlsBar: some View {
        HStack(spacing: 0) {
            Spacer()
            controlButton(
                icon:   audioRecorder.state == .recording ? "pause.circle.fill" : "play.circle.fill",
                label:  audioRecorder.state == .recording ? "Pause"             : "Resume",
                color:  DesignTokens.Colors.textPrimary(for: colorScheme),
                action: togglePause
            )
            Spacer()
            controlButton(
                icon:     "stop.circle.fill",
                label:    "Stop",
                color:    DesignTokens.Colors.stateRecording(for: colorScheme),
                action:   { audioRecorder.stopRecording() },
                iconSize: 36
            )
            Spacer()
            controlButton(
                icon:   "camera.fill",
                label:  "Photo",
                color:  DesignTokens.Colors.textSecondary(for: colorScheme),
                action: { showCamera = true }
            )
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.backgroundSecondary(for: colorScheme))
    }

    // MARK: – Toolbar menu

    private var sessionMenu: some View {
        Menu {
            if audioRecorder.state == .recording {
                Button(action: { audioRecorder.pauseRecording() }) {
                    Label("Privacy Pause", systemImage: "lock.shield")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
        }
    }

    // MARK: – Helpers

    private func togglePause() {
        audioRecorder.state == .recording
            ? audioRecorder.pauseRecording()
            : audioRecorder.resumeRecording()
    }

    private func controlButton(icon: String, label: String, color: Color,
                               action: @escaping () -> Void, iconSize: CGFloat = 28) -> some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(color)
                Text(label)
                    .font(DesignTokens.Typography.tiny)
                    .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
            }
        }
        .frame(width: 64)
    }
}
