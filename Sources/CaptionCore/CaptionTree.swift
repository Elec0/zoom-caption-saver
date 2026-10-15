import Foundation

/// Our normalized accessibility observation, not a Zoom private data structure.
public struct CaptionNode: Codable {
    public let id: String
    public let role: String
    public let title: String?
    public let label: String?
    public let value: String?
    public let children: [CaptionNode]

    public init(id: String, role: String, title: String? = nil, label: String? = nil,
                value: String? = nil, children: [CaptionNode] = []) {
        self.id = id
        self.role = role
        self.title = title
        self.label = label
        self.value = value
        self.children = children
    }
}

public struct CaptionTree {
    /// Restricts extraction to the table identified in the live Zoom test. Other
    /// meeting text, including chat and participant controls, never becomes captions.
    public static func rows(in root: CaptionNode) -> [CaptionRow] {
        if root.role == "AXTable", [root.title, root.label, root.value].contains("Closed caption subtitles") {
            return captionRows(in: root)
        }
        return root.children.flatMap { rows(in: $0) }
    }

    /// Uses row identity rather than global text deduplication, since speakers can
    /// legitimately repeat a sentence. Zoom's combined accessibility text is kept.
    private static func captionRows(in node: CaptionNode) -> [CaptionRow] {
        if node.role == "AXRow" {
            let text = staticText(in: node).joined(separator: "\n")
            return text.isEmpty ? [] : [CaptionRow(id: node.id, text: text)]
        }
        return node.children.flatMap { captionRows(in: $0) }
    }

    /// Reads actual nonempty scalar strings, without splitting or inventing names.
    private static func staticText(in node: CaptionNode) -> [String] {
        if node.role == "AXStaticText" {
            for candidate in [node.value, node.title, node.label] {
                if let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return [candidate]
                }
            }
        }
        return node.children.flatMap { staticText(in: $0) }
    }
}
