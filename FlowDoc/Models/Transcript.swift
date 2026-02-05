import Foundation

struct Transcript: Identifiable, Codable {
    let id:        UUID
    let sessionID: UUID
    var  segments: [Segment]

    var fullText: String {
        segments.map { $0.text }.joined(separator: " ")
    }

    init(id: UUID = UUID(), sessionID: UUID, segments: [Segment] = []) {
        self.id        = id
        self.sessionID = sessionID
        self.segments  = segments
    }
}
