import Foundation

struct Segment: Identifiable, Codable {
    let id:         UUID
    let text:       String
    let startTime:  TimeInterval   // seconds into the session
    let endTime:    TimeInterval
    var  speakerID: String?
    let confidence: Float
    var  isEdited:  Bool

    var formattedTimestamp: String {
        let total = Int(startTime)
        let h = total / 3600
        let m = total / 60 % 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    init(
        id:         UUID            = UUID(),
        text:       String,
        startTime:  TimeInterval,
        endTime:    TimeInterval,
        speakerID:  String?         = nil,
        confidence: Float           = 1.0,
        isEdited:   Bool            = false
    ) {
        self.id         = id
        self.text       = text
        self.startTime  = startTime
        self.endTime    = endTime
        self.speakerID  = speakerID
        self.confidence = confidence
        self.isEdited   = isEdited
    }
}
