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
