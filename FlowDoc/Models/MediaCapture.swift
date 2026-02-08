import Foundation

enum MediaType: String, Codable {
    case photo
    case video
}

struct MediaCapture: Identifiable, Codable {
    let id:              UUID
    let sessionID:       UUID
    let type:            MediaType
    let timestamp:       Date
    let transcriptOffset: TimeInterval   // seconds into the session
    let fileURL:         URL
    var  caption:        String?
    var  tags:           [String]

    /// Resolves the file URL against the current app container.
    /// The stored `fileURL` may have a stale container UUID after reinstall/update.
    var resolvedFileURL: URL {
        // Extract the relative portion after "Documents/"
        let path = fileURL.path
        if let range = path.range(of: "/Documents/") {
            let relativePath = String(path[range.upperBound...])
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return docs.appendingPathComponent(relativePath)
        }
        return fileURL
    }

    init(
        id:               UUID            = UUID(),
        sessionID:        UUID,
        type:             MediaType,
        timestamp:        Date            = Date(),
        transcriptOffset: TimeInterval,
        fileURL:          URL,
        caption:          String?         = nil,
        tags:             [String]        = []
    ) {
        self.id               = id
        self.sessionID        = sessionID
        self.type             = type
        self.timestamp        = timestamp
        self.transcriptOffset = transcriptOffset
        self.fileURL          = fileURL
        self.caption          = caption
        self.tags             = tags
    }
}
