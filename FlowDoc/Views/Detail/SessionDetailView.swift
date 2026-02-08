import SwiftUI
import UIKit

struct SessionDetailView: View {
    let session: Session
    @Environment(\.colorScheme) var colorScheme
    @State private var segments:       [Segment] = []
    @State private var mediaCaptures:  [MediaCapture] = []
    @State private var cachedHTML:     String     = ""
    @State private var copied:         Bool       = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    sectionDivider
                    summarySection
                    sectionDivider
                    mediaSection
                    sectionDivider
                    transcriptSection
                }
            }
            exportBar
        }
        .frame(maxHeight: .infinity)
        .background(DesignTokens.Colors.backgroundPrimary(for: colorScheme))
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            DesignTokens.Colors.backgroundPrimary(for: colorScheme),
            for: .navigationBar
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: copyToClipboard) {
                        Label("Copy HTML", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                }
                .accessibilityLabel("Session options")
            }
        }
        .onAppear { loadData() }
    }

    // MARK: – Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Session")
                    .font(DesignTokens.Typography.title1)
                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                Spacer()
                StatusBadge(status: .completed)
            }

            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(session.startTime.formatted(date: .long, time: .shortened))
                    .font(DesignTokens.Typography.small)
                    .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                Text("\u{00B7}")
                    .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                Text(session.formattedDuration)
                    .font(DesignTokens.Typography.small)
                    .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
            }

            if !session.tags.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(session.tags, id: \.self) { TagView(text: $0) }
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session, \(session.startTime.formatted(date: .long, time: .shortened)), duration \(session.formattedDuration)")
    }

    // MARK: – Summary  (placeholder – AI summaries arrive in Phase 2)

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("Summary")
                    .font(DesignTokens.Typography.title2)
                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                Text("Phase 2")
                    .font(DesignTokens.Typography.tiny)
                    .foregroundStyle(DesignTokens.Colors.accentPrimary(for: colorScheme))
                    .padding(.horizontal, 6)
                    .padding(.vertical,   2)
                    .background(DesignTokens.Colors.accentPrimary(for: colorScheme).opacity(0.12))
                    .cornerRadius(4)
            }
            Text("AI-generated key points and action items will appear here.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: – Media

    private var mediaSection: some View {
        MediaGridView(mediaItems: mediaCaptures, sessionID: session.id)
            .padding(DesignTokens.Spacing.lg)
    }

    // MARK: – Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("Transcript")
                    .font(DesignTokens.Typography.title2)
                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                if !segments.isEmpty {
                    Text("\(segments.count) segments")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                }
            }

            if segments.isEmpty {
                Text("No transcript segments recorded.")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
            } else {
                ForEach(segments) { TranscriptRow(segment: $0) }
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: – Export bar

    private var exportBar: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button(action: copyToClipboard) {
                Text(copied ? "Copied!" : "Export HTML")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundStyle(DesignTokens.Colors.backgroundPrimaryLight)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(DesignTokens.Colors.accentPrimary(for: colorScheme))
                    .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .accessibilityLabel(copied ? "HTML copied to clipboard" : "Export session as HTML")

            ShareLink(item: cachedHTML, preview: SharePreview("FlowDoc Session")) {
                Text("Share")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundStyle(DesignTokens.Colors.accentPrimary(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(DesignTokens.Colors.accentPrimary(for: colorScheme).opacity(0.12))
                    .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .accessibilityLabel("Share session")
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical,   DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary(for: colorScheme))
    }

    // MARK: – Helpers

    private var sectionDivider: some View {
        Divider().padding(.horizontal, DesignTokens.Spacing.lg)
    }

    private func loadData() {
        segments       = DatabaseManager.shared.fetchSegments(for: session.id)
        mediaCaptures  = DatabaseManager.shared.fetchMediaCaptures(for: session.id)
        cachedHTML     = HTMLExporter.shared.generateHTML(session: session, segments: segments)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = cachedHTML
        copied = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
