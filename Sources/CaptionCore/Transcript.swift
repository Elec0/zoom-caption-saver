import Foundation

public struct CaptionRow: Equatable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct TranscriptEntry: Equatable {
    public let firstSeen: Date
    public var text: String
}

public struct Transcript {
    public private(set) var entries: [TranscriptEntry] = []
    private var positions: [String: Int] = [:]
    private var previousIDs: Set<String> = []

    public init() {}

    /// Applies row revisions without duplicating repeated polls. A disappeared row
    /// reused with different text starts a new entry, preserving earlier captions.
    public mutating func observe(_ rows: [CaptionRow], at date: Date) -> Bool {
        var changed = false
        for row in rows where !row.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let index = positions[row.id] {
                if entries[index].text == row.text { continue }
                if previousIDs.contains(row.id) {
                    entries[index].text = row.text
                    changed = true
                    continue
                }
            }
            positions[row.id] = entries.count
            entries.append(TranscriptEntry(firstSeen: date, text: row.text))
            changed = true
        }
        previousIDs = Set(rows.map(\.id))
        return changed
    }
}
