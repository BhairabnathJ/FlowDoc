import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @ObservedObject var transcription = TranscriptionEngine.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 0) {
            timerSection

            Divider()
                .padding(.horizontal, DesignTokens.Spacing.lg)

            ScrollView {
                ScrollViewReader { proxy in
                    transcriptContent
                        .onChange(of: transcription.segments.count) { _, _ in
                            if let lastId = transcription.segments.last?.id {
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
        .onChange(of: audioRecorder.isRecording) { _, isRecording in
            if !isRecording { dismiss() }
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
                if audioRecorder.isRecording && !audioRecorder.isPaused {
                    RecordingDot()
                }
                StatusBadge(status: audioRecorder.isPaused ? .paused : .recording)
            }

            Text(formatDuration(audioRecorder.duration))
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

            // Model loading state
            if !transcription.isModelLoaded {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ProgressView()
                        .tint(DesignTokens.Colors.accentPrimary(for: colorScheme))
                    Text("Loading transcription model...")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DesignTokens.Spacing.xl)
            } else if transcription.segments.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                    Text("Start speaking to see live transcription")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DesignTokens.Spacing.xl)
            } else {
                ForEach(transcription.segments) { segment in
                    TranscriptRow(segment: segment)
                        .id(segment.id)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.xxl)
    }

    // MARK: – Controls

    private var controlsBar: some View {
        HStack(spacing: 0) {
            Spacer()
            controlButton(
                icon: audioRecorder.isPaused ? "play.circle.fill" : "pause.circle.fill",
                label: audioRecorder.isPaused ? "Resume" : "Pause",
                color: DesignTokens.Colors.textPrimary(for: colorScheme),
                action: togglePause
            )
            Spacer()
            controlButton(
                icon: "stop.circle.fill",
                label: "Stop",
                color: DesignTokens.Colors.stateRecording(for: colorScheme),
                action: { audioRecorder.stopRecording() },
                iconSize: 36
            )
            Spacer()
            controlButton(
                icon: "camera.fill",
                label: "Photo",
                color: DesignTokens.Colors.textSecondary(for: colorScheme),
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
            if audioRecorder.isRecording && !audioRecorder.isPaused {
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
        if audioRecorder.isPaused {
            audioRecorder.resumeRecording()
        } else {
            audioRecorder.pauseRecording()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = total / 60 % 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
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
