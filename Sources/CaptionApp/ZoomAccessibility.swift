import AppKit
import ApplicationServices
import CaptionCore
import Foundation

struct ZoomObservation {
    let meeting: String?
    let table: CaptionNode?
    let zoomRunning: Bool
}

enum CaptureError: LocalizedError {
    case permission
    case accessibility(Int32)
    case incomplete

    var errorDescription: String? {
        switch self {
        case .permission: return "Accessibility required"
        case .accessibility(let code): return "Zoom read unavailable (\(code))"
        case .incomplete: return "Caption scan incomplete; retrying"
        }
    }
}

/// Reads Zoom's caption table without actions, screenshots, audio, or attachment.
final class ZoomAccessibility {
    private var meetingWindow: AXUIElement?
    private var meetingPID: pid_t?
    private var meetingKey: String?
    private var rowIDs: [CFHashCode: [(AXUIElement, String)]] = [:]
    private var nextRow = 0
    private var nodeBudget = 0
    private var deadline = Date()

    /// A read failure differs from meeting end so transient errors retain history.
    func poll() throws -> ZoomObservation {
        guard AXIsProcessTrusted() else { throw CaptureError.permission }
        nodeBudget = 4000
        deadline = Date().addingTimeInterval(3)
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "us.zoom.xos")
        var windows: [(pid_t, AXUIElement)] = []
        for app in apps {
            let application = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(application, 0.5)
            for window in try elements(application, kAXWindowsAttribute, required: true) {
                windows.append((app.processIdentifier, window))
            }
        }
        guard let (pid, main) = windows.first(where: {
            text($0.1, kAXIdentifierAttribute) == "zm.meeting.window.main"
        }) else {
            clearMeeting()
            return ZoomObservation(meeting: nil, table: nil, zoomRunning: !apps.isEmpty)
        }
        if meetingPID != pid || meetingWindow == nil || !CFEqual(meetingWindow, main) {
            clearMeeting()
            meetingWindow = main
            meetingPID = pid
            meetingKey = UUID().uuidString
        }
        // Pinned captions are inside the meeting; pop-out captions use another
        // window. Read one table to avoid recording the same captions twice.
        if let table = try findTable(main) {
            return ZoomObservation(meeting: meetingKey, table: try snapshot(table), zoomRunning: true)
        }
        for (_, window) in windows where !CFEqual(window, main) {
            if let table = try findTable(window) {
                return ZoomObservation(meeting: meetingKey, table: try snapshot(table), zoomRunning: true)
            }
        }
        return ZoomObservation(meeting: meetingKey, table: nil, zoomRunning: true)
    }

    /// Native row identities distinguish repeated words from repeated polls.
    private func rowID(_ element: AXUIElement) -> String {
        let hash = CFHash(element)
        if let found = rowIDs[hash]?.first(where: { CFEqual($0.0, element) }) { return found.1 }
        nextRow += 1
        let id = "row-\(nextRow)"
        rowIDs[hash, default: []].append((element, id))
        return id
    }

    private func clearMeeting() {
        meetingWindow = nil
        meetingPID = nil
        meetingKey = nil
        rowIDs.removeAll()
        nextRow = 0
    }

    /// Rejects partial scans rather than reporting incomplete captions as empty.
    private func checkBudget() throws {
        nodeBudget -= 1
        guard nodeBudget >= 0, Date() < deadline else { throw CaptureError.incomplete }
    }

    /// Searches metadata; unrelated chat or calendar text is never collected.
    private func findTable(_ node: AXUIElement, depth: Int = 0) throws -> AXUIElement? {
        try checkBudget()
        guard depth <= 30 else { throw CaptureError.incomplete }
        if text(node, kAXRoleAttribute) == "AXTable",
           [text(node, kAXTitleAttribute), text(node, kAXDescriptionAttribute),
            text(node, kAXValueAttribute)].contains("Closed caption subtitles") { return node }
        for child in try elements(node, kAXChildrenAttribute) {
            if let table = try findTable(child, depth: depth + 1) { return table }
        }
        return nil
    }

    /// Preserves actual caption attributes for extraction and local diagnostics.
    private func snapshot(_ node: AXUIElement, depth: Int = 0) throws -> CaptionNode {
        try checkBudget()
        guard depth <= 30 else { throw CaptureError.incomplete }
        let role = text(node, kAXRoleAttribute) ?? ""
        let children = try elements(node, kAXChildrenAttribute).map { try snapshot($0, depth: depth + 1) }
        return CaptionNode(id: role == "AXRow" ? rowID(node) : "", role: role,
                           title: text(node, kAXTitleAttribute), label: text(node, kAXDescriptionAttribute),
                           value: text(node, kAXValueAttribute), children: children)
    }

    /// Optional native attributes may be missing or nontextual.
    private func text(_ node: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(node, name as CFString, &value) == .success else { return nil }
        if let value = value as? String { return value }
        if let value = value as? NSAttributedString { return value.string }
        return nil
    }

    /// Unsupported children are leaves; transport and permission errors fail.
    private func elements(_ node: AXUIElement, _ name: String, required: Bool = false) throws -> [AXUIElement] {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(node, name as CFString, &value)
        if !required && (error == .attributeUnsupported || error == .noValue) { return [] }
        guard error == .success, let values = value as? [AXUIElement] else {
            throw CaptureError.accessibility(error.rawValue)
        }
        return values
    }
}
