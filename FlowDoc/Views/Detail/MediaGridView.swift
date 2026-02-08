import SwiftUI
import UIKit

/// Grid of captured photos/videos.  Shows an empty-state row when no media exists.
struct MediaGridView: View {
    let mediaItems: [MediaCapture]
    let sessionID: UUID
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedCapture: MediaCapture?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("Media")
                    .font(DesignTokens.Typography.title2)
                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                if !mediaItems.isEmpty {
                    Text("(\(mediaItems.count))")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                }
            }

            if mediaItems.isEmpty {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "camera")
                        .font(.system(size: 18))
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                    Text("No photos captured during this session")
                        .font(DesignTokens.Typography.small)
                        .foregroundStyle(DesignTokens.Colors.textTertiary(for: colorScheme))
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: DesignTokens.Spacing.sm)
                ], spacing: DesignTokens.Spacing.sm) {
                    ForEach(mediaItems) { item in
                        MediaThumbnail(capture: item, sessionID: sessionID, colorScheme: colorScheme)
                            .onTapGesture {
                                selectedCapture = item
                            }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedCapture) { capture in
            MediaFullScreenView(capture: capture)
        }
    }
}

/// Individual media thumbnail that loads and displays the actual image
struct MediaThumbnail: View {
    let capture: MediaCapture
    let sessionID: UUID
    let colorScheme: ColorScheme

    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
            .fill(DesignTokens.Colors.backgroundTertiary(for: colorScheme))
            .frame(height: 100)
            .overlay {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipped()
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                } else {
                    ProgressView()
                        .tint(DesignTokens.Colors.textTertiary(for: colorScheme))
                }
            }
            .onAppear {
                loadImage()
            }
    }

    private func loadImage() {
        guard let data = try? Data(contentsOf: capture.resolvedFileURL),
              let uiImage = UIImage(data: data) else {
            print("Failed to load image from \(capture.resolvedFileURL)")
            return
        }
        image = uiImage
    }
}

// MARK: - Full Screen Image Viewer

struct MediaFullScreenView: View {
    let capture: MediaCapture
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = loadImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .onTapGesture(count: 2) {
                        withAnimation {
                            scale = scale > 1.0 ? 1.0 : 2.0
                        }
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Unable to load image")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(DesignTokens.Spacing.lg)
                    }
                }
                Spacer()

                // Timestamp
                Text("Captured at \(Session.formatDuration(capture.transcriptOffset))")
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(DesignTokens.Spacing.lg)
            }
        }
    }

    private func loadImage() -> UIImage? {
        guard let data = try? Data(contentsOf: capture.resolvedFileURL) else { return nil }
        return UIImage(data: data)
    }
}
