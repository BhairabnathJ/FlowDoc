import SwiftUI
import UIKit

/// Grid of captured photos/videos.  Shows an empty-state row when no media exists.
struct MediaGridView: View {
    let mediaItems: [MediaCapture]
    let sessionID: UUID
    @Environment(\.colorScheme) var colorScheme

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
                    }
                }
            }
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
        // Load image from fileURL
        guard let data = try? Data(contentsOf: capture.fileURL),
              let uiImage = UIImage(data: data) else {
            print("Failed to load image from \(capture.fileURL)")
            return
        }
        image = uiImage
    }
}
