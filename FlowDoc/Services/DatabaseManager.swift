import Foundation
import Combine

/// JSON-backed persistence for sessions and transcript segments.
/// Public interface matches what a future SQLite.swift swap would require;
/// only the private I/O layer needs changing at that point.
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    private let sessionsURL: URL
    private let segmentsURL: URL

    private var sessions: [Session]                = []
    private var segments: [String: [Segment]]      = [:]   // transcriptId → segments

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        sessionsURL = docs.appendingPathComponent("flowdoc_sessions.json")
        segmentsURL = docs.appendingPathComponent("flowdoc_segments.json")
        loadFromDisk()
        print("DatabaseManager initialised – \(sessions.count) session(s) loaded")
    }

    // MARK: - Session operations

    func saveSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        persistSessions()
        print("Session saved: \(session.id)")
    }

    func updateSession(_ session: Session) {
        guard let idx = sessions.firstIndex(where: { $0.id == session.id }) else {
            print("Session not found for update: \(session.id)")
            return
        }
        sessions[idx] = session
        persistSessions()
        print("Session updated: \(session.id)")
    }

    /// All sessions, newest first.
    func fetchAllSessions() -> [Session] {
        sessions.sorted { $0.startTime > $1.startTime }
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        persistSessions()
        // Also clean up segments for this session's transcript
        segments.removeValue(forKey: id.uuidString)
        persistSegments()
        print("Session deleted: \(id)")
    }

    // MARK: - Segment operations

    func saveSegment(_ segment: Segment, transcriptId: UUID) {
        let key = transcriptId.uuidString
        segments[key, default: []].append(segment)
        persistSegments()
    }

    /// Segments for a given transcript, ordered by start time.
    func fetchSegments(for transcriptId: UUID) -> [Segment] {
        (segments[transcriptId.uuidString] ?? [])
            .sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Media Capture operations

    func saveMediaCapture(_ capture: MediaCapture, for sessionID: UUID) {
        // Media captures are stored in the Media directory, one JSON file per session
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaDir = docs.appendingPathComponent("Media").appendingPathComponent(sessionID.uuidString)
        let capturesFile = mediaDir.appendingPathComponent("captures.json")

        var captures = fetchMediaCaptures(for: sessionID)
        captures.append(capture)

        do {
            let data = try JSONEncoder().encode(captures)
            try data.write(to: capturesFile)
            print("Media capture saved: \(capture.id)")
        } catch {
            print("Failed to persist media capture: \(error)")
        }
    }

    func fetchMediaCaptures(for sessionID: UUID) -> [MediaCapture] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaDir = docs.appendingPathComponent("Media").appendingPathComponent(sessionID.uuidString)
        let capturesFile = mediaDir.appendingPathComponent("captures.json")

        guard FileManager.default.fileExists(atPath: capturesFile.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: capturesFile)
            let captures = try JSONDecoder().decode([MediaCapture].self, from: data)
            return captures.sorted { $0.timestamp < $1.timestamp }
        } catch {
            print("Failed to load media captures: \(error)")
            return []
        }
    }

    // MARK: - Disk I/O

    private func persistSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsURL)
        } catch {
            print("Failed to persist sessions: \(error)")
        }
    }

    private func persistSegments() {
        do {
            let data = try JSONEncoder().encode(segments)
            try data.write(to: segmentsURL)
        } catch {
            print("Failed to persist segments: \(error)")
        }
    }

    private func loadFromDisk() {
        if let data = try? Data(contentsOf: sessionsURL) {
            sessions = (try? JSONDecoder().decode([Session].self, from: data)) ?? []
        }
        if let data = try? Data(contentsOf: segmentsURL) {
            segments = (try? JSONDecoder().decode([String: [Segment]].self, from: data)) ?? [:]
        }
    }
}
