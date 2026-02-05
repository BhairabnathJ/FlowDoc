import Foundation

struct Session: Identifiable, Codable {
    let id:           UUID
    let startTime:    Date
    var  endTime:     Date?
    var  location:    String?
    var  participants: [String]
    var  tags:        [String]
    var  isArchived:  Bool

    // Live duration – uses current time when session has not yet ended.
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        Session.formatDuration(duration)
    }

    /// Shared formatter used by both Session and the live recording timer.
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = total / 60 % 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    init(
        id:           UUID     = UUID(),
        startTime:    Date     = Date(),
        endTime:      Date?    = nil,
        location:     String?  = nil,
        participants: [String] = [],
        tags:         [String] = [],
        isArchived:   Bool     = false
    ) {
        self.id           = id
        self.startTime    = startTime
        self.endTime      = endTime
        self.location     = location
        self.participants = participants
        self.tags         = tags
        self.isArchived   = isArchived
    }
}
