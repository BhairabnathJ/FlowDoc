import SwiftUI
import UIKit

struct HomeView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @State          private var sessions:  [Session] = []
    @State          private var searchText = ""
    @Environment(\.colorScheme) var colorScheme

    /// Past sessions excluding whichever session is currently active.
    private var pastSessions: [Session] {
        let base = sessions.filter { $0.id != audioRecorder.currentSession?.id }
        guard !searchText.isEmpty else { return base }
        return base.filter { session in
            session.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    // --- active-session card ---
                    if audioRecorder.hasActiveSession {
                        Section {
                            NavigationLink {
                                RecordingView()
                                    .environmentObject(audioRecorder)
                            } label: {
                                ActiveSessionCard(audioRecorder: audioRecorder)
                            }
                            .listRowInsets(EdgeInsets(
                                top: DesignTokens.Spacing.sm,
                                leading: DesignTokens.Spacing.lg,
                                bottom: DesignTokens.Spacing.sm,
                                trailing: DesignTokens.Spacing.lg
                            ))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }

                    // --- session list  OR  empty state ---
                    if !pastSessions.isEmpty {
                        Section {
                            ForEach(pastSessions) { session in
                                NavigationLink {
                                    SessionDetailView(session: session)
                                } label: {
                                    SessionCard(session: session)
                                }
                                .listRowInsets(EdgeInsets(
                                    top: DesignTokens.Spacing.xs,
                                    leading: DesignTokens.Spacing.lg,
                                    bottom: DesignTokens.Spacing.xs,
                                    trailing: DesignTokens.Spacing.lg
                                ))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteSession(session)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        exportSession(session)
                                    } label: {
                                        Label("Export", systemImage: "square.and.arrow.up")
                                    }
                                    .tint(DesignTokens.Colors.accentPrimaryLight)
                                }
                                .accessibilityLabel("Session from \(session.startTime.formatted(date: .abbreviated, time: .omitted)), duration \(session.formattedDuration)")
                            }
                        } header: {
                            Text("Recent Sessions")
                                .font(DesignTokens.Typography.title2)
                                .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                                .textCase(nil)
                        }
                    } else if !audioRecorder.hasActiveSession {
                        Section {
                            emptyState
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // --- FAB (hidden while a session is active) ---
                if !audioRecorder.hasActiveSession {
                    fab
                }
            }
            .background(DesignTokens.Colors.backgroundPrimary(for: colorScheme))
            .navigationTitle("FlowDoc")
            .searchable(text: $searchText, prompt: "Search sessions")
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
                    .accessibilityLabel("Settings")
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
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            audioRecorder.startRecording()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.backgroundPrimaryLight) // cream text
                .frame(width: 56, height: 56) // >44pt touch target
                .background(DesignTokens.Colors.accentPrimary(for: colorScheme))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .accessibilityLabel("New Session")
                .accessibilityHint("Begins a new recording session")
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
        .frame(maxWidth: .infinity)
        .padding(.top,        100)
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }

    // MARK: - Data

    private func loadSessions() {
        sessions = DatabaseManager.shared.fetchAllSessions()
    }

    private func deleteSession(_ session: Session) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DatabaseManager.shared.deleteSession(session.id)
        loadSessions()
    }

    private func exportSession(_ session: Session) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let segments = DatabaseManager.shared.fetchSegments(for: session.id)
        let html = HTMLExporter.shared.generateHTML(session: session, segments: segments)
        UIPasteboard.general.string = html
    }
}

// MARK: - ActiveSessionCard

/// Card shown while a session is in progress.
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
                cameraButton
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active session, \(audioRecorder.state == .recording ? "recording" : "paused"), elapsed time \(audioRecorder.formattedElapsedTime)")
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
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            togglePause()
        }) {
            Label(
                audioRecorder.state == .recording ? "Pause"  : "Resume",
                systemImage: audioRecorder.state == .recording ? "pause.circle.fill" : "play.circle.fill"
            )
            .labelStyle(.iconOnly)
            .font(.title2)
            .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
        }
        .accessibilityLabel(audioRecorder.state == .recording ? "Pause recording" : "Resume recording")
    }

    private var stopButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            audioRecorder.stopRecording()
        }) {
            Label("Stop", systemImage: "stop.circle.fill")
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(DesignTokens.Colors.stateRecording(for: colorScheme))
        }
        .accessibilityLabel("Stop recording")
        .accessibilityHint("Ends the current recording session")
    }

    private var cameraButton: some View {
        NavigationLink {
            if let sessionID = audioRecorder.currentSession?.id {
                CameraView(sessionID: sessionID)
                    .environmentObject(audioRecorder)
            }
        } label: {
            Label("Photo", systemImage: "camera.fill")
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
        }
        .accessibilityLabel("Take photo")
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
