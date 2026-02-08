import SwiftUI

struct HomeView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @Environment(\.colorScheme) var colorScheme
    @State private var navigationPath: [FlowDocRoute] = []
    @State private var sessions: [Session] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                mainContent
                floatingButton
            }
            .background(DesignTokens.Colors.backgroundPrimary(for: colorScheme))
            .navigationDestination(for: FlowDocRoute.self) { route in
                destinationView(for: route)
            }
        }
        .onAppear {
            sessions = DatabaseManager.shared.fetchAllSessions()
            if audioRecorder.isRecording && !navigationPath.contains(.recording) {
                navigationPath.append(.recording)
            }
        }
        .onChange(of: audioRecorder.isRecording) { _, newValue in
            if newValue && !navigationPath.contains(.recording) {
                navigationPath.append(.recording)
            }
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                headerSection
                activeSessionSection
                pastSessionsSection
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, 80)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("FlowDoc")
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Colors.textPrimary(for: colorScheme))
            Spacer()
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }

    // MARK: - Active Session Section
    @ViewBuilder
    private var activeSessionSection: some View {
        if audioRecorder.isRecording {
            NavigationLink(value: FlowDocRoute.recording) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        if !audioRecorder.isPaused {
                            RecordingDot()
                        }
                        StatusBadge(status: audioRecorder.isPaused ? .paused : .recording)
                        Spacer()
                    }

                    Text(Session.formatDuration(audioRecorder.duration))
                        .font(.system(size: 32, weight: .semibold).monospacedDigit())
                        .foregroundColor(DesignTokens.Colors.textPrimary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Tap to return to recording")
                        .font(DesignTokens.Typography.small)
                        .foregroundColor(DesignTokens.Colors.textSecondary(for: colorScheme))
                }
                .padding(DesignTokens.Spacing.lg)
                .background(DesignTokens.Colors.backgroundSecondary(for: colorScheme))
                .cornerRadius(DesignTokens.CornerRadius.lg)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Past Sessions Section
    private var pastSessionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Past Sessions")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary(for: colorScheme))
            pastSessionsList
        }
    }

    @ViewBuilder
    private var pastSessionsList: some View {
        if sessions.isEmpty {
            emptyStateView
        } else {
            sessionsGrid
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text("No sessions yet")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary(for: colorScheme))
            Text("Tap the button below to start your first recording")
                .font(DesignTokens.Typography.small)
                .foregroundColor(DesignTokens.Colors.textTertiary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, DesignTokens.Spacing.xl)
    }

    private var sessionsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: DesignTokens.Spacing.md
        ) {
            ForEach(sessions) { session in
                NavigationLink(value: FlowDocRoute.sessionDetail(session.id)) {
                    SessionCard(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Floating Button
    private var floatingButton: some View {
        Button(action: startNewSession) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("New Session")
                    .font(DesignTokens.Typography.body)
            }
            .foregroundColor(.white)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.accentPrimary(for: colorScheme))
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .padding(.bottom, DesignTokens.Spacing.lg)
        .disabled(audioRecorder.isRecording)
        .opacity(audioRecorder.isRecording ? 0.5 : 1.0)
    }

    // MARK: - Navigation Destinations
    @ViewBuilder
    private func destinationView(for route: FlowDocRoute) -> some View {
        switch route {
        case .recording:
            RecordingView()
        case .sessionDetail(let sessionId):
            if let session = sessions.first(where: { $0.id == sessionId }) {
                SessionDetailView(session: session)
            } else {
                Text("Session not found")
                    .foregroundColor(DesignTokens.Colors.textSecondary(for: colorScheme))
            }
        }
    }

    // MARK: - Actions
    private func startNewSession() {
        audioRecorder.startRecording()
        if !navigationPath.contains(.recording) {
            navigationPath.append(.recording)
        }
    }
}

// MARK: - FlowDocRoute
enum FlowDocRoute: Hashable {
    case recording
    case sessionDetail(UUID)
}
