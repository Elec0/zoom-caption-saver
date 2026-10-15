import Foundation

public final class MeetingRecorder {
    public private(set) var currentFile: URL?
    public private(set) var transcript = Transcript()
    public let directory: URL
    private var meeting: String?
    private var dirty = false

    public init(directory: URL) {
        self.directory = directory
    }

    /// Saves each observed change atomically to one file per meeting. Empty polls
    /// retain history; an absent meeting ends the session. Failed writes stay dirty
    /// so a later poll retries without discarding the in-memory transcript.
    public func observe(meeting: String?, rows: [CaptionRow], at date: Date) throws {
        if meeting != self.meeting {
            // Do not discard unsaved captions when Zoom closes during a disk error.
            if dirty { try save() }
            self.meeting = meeting
            currentFile = nil
            transcript = Transcript()
            dirty = false
        }
        guard meeting != nil else { return }
        if transcript.observe(rows, at: date) { dirty = true }
        guard dirty else { return }

        if currentFile == nil {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                     attributes: [.posixPermissions: 0o700])
            let name = ISO8601DateFormatter().string(from: date).replacingOccurrences(of: ":", with: "-")
            currentFile = directory.appendingPathComponent("zoom-\(name)-\(UUID().uuidString.prefix(8)).txt")
        }
        try save()
    }

    /// Replaces the current file only after a complete UTF-8 transcript is ready.
    private func save() throws {
        guard let file = currentFile else { return }
        let formatter = ISO8601DateFormatter()
        var text = "Zoom visible captions\nTimestamps: first observed locally, UTC; not exact speech timing.\n"
        text += "Speaker names and wording are preserved as exposed by Zoom.\n\n"
        for entry in transcript.entries {
            text += "[\(formatter.string(from: entry.firstSeen))] \(entry.text)\n\n"
        }
        try Data(text.utf8).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        dirty = false
    }
}
