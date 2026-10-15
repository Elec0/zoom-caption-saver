import AppKit
import CaptionCore
import Foundation

/// Serial capture/file work stays off the menu UI thread and cannot overlap.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let worker = DispatchQueue(label: "local.zoom-caption-saver.capture")
    private let reader = ZoomAccessibility()
    private var timer: DispatchSourceTimer?
    private var item: NSStatusItem!
    private var status: NSMenuItem!
    private var latestFileItem: NSMenuItem!
    private var latestFile: URL?
    private var table: CaptionNode?
    private let root: URL
    private let recorder: MeetingRecorder

    override init() {
        root = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        recorder = MeetingRecorder(directory: root.appendingPathComponent("transcripts", isDirectory: true))
        super.init()
    }

    /// Watches immediately; the user alone controls macOS Accessibility access.
    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        guard !others.contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) else {
            NSApp.terminate(nil)
            return
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "CC"
        let menu = NSMenu()
        status = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
        menu.addItem(status)
        menu.addItem(NSMenuItem.separator())
        add("Open Transcript Folder", #selector(openFolder), to: menu)
        latestFileItem = add("Open Latest Transcript", #selector(openLatest), to: menu)
        latestFileItem.isEnabled = false
        add("Save Caption Diagnostic", #selector(saveDiagnostic), to: menu)
        add("Accessibility Settings…", #selector(openAccessibility), to: menu)
        menu.addItem(NSMenuItem.separator())
        add("Quit", #selector(quit), to: menu)
        item.menu = menu
        let timer = DispatchSource.makeTimerSource(queue: worker)
        timer.schedule(deadline: .now(), repeating: .milliseconds(750))
        timer.setEventHandler { [weak self] in self?.poll() }
        self.timer = timer
        timer.resume()
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: "")
        row.target = self
        menu.addItem(row)
        return row
    }

    /// Failed reads preserve the current meeting and saved history for retry.
    private func poll() {
        do {
            let observation = try reader.poll()
            table = observation.table
            let rows = observation.table.map { CaptionTree.rows(in: $0) } ?? []
            try recorder.observe(meeting: observation.meeting, rows: rows, at: Date())
            let message: String
            if !observation.zoomRunning { message = "Waiting for Zoom" }
            else if observation.meeting == nil { message = "Waiting for a meeting" }
            else if rows.isEmpty { message = "Waiting for displayed captions" }
            else { message = "Recording captions · \(recorder.transcript.entries.count) rows" }
            update(message, file: recorder.currentFile)
        } catch { update(error.localizedDescription, file: recorder.currentFile) }
    }

    /// Status follows actual reads/writes rather than assuming capture succeeded.
    private func update(_ message: String, file: URL?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.status.title = message
            self.item.button?.title = message.hasPrefix("Recording") ? "CC ●" : "CC"
            if let file { self.latestFile = file }
            self.latestFileItem.isEnabled = self.latestFile != nil
            self.item.button?.toolTip = "Zoom Caption Saver: " + message
        }
    }

    @objc private func openFolder() {
        do {
            try FileManager.default.createDirectory(at: recorder.directory, withIntermediateDirectories: true,
                                                     attributes: [.posixPermissions: 0o700])
            NSWorkspace.shared.open(recorder.directory)
        } catch { showError(error.localizedDescription) }
    }

    @objc private func openLatest() {
        if let latestFile { NSWorkspace.shared.open(latestFile) }
    }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Writes only the caption subtree, never other meeting or chat UI.
    @objc private func saveDiagnostic() {
        worker.async { [weak self] in
            guard let self else { return }
            do {
                guard let table = self.table else {
                    self.showError("No caption table is available. Check permission and enable Zoom captions.")
                    return
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let folder = self.root.appendingPathComponent("evidence", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let file = folder.appendingPathComponent("caption-table-\(UUID().uuidString.prefix(8)).json")
                try encoder.encode(table).write(to: file, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
                DispatchQueue.main.async { NSWorkspace.shared.activateFileViewerSelecting([file]) }
            } catch { self.showError(error.localizedDescription) }
        }
    }

    /// Flushes pending changes before exit; a save failure keeps the app running.
    @objc private func quit() {
        worker.async { [weak self] in
            guard let self else { return }
            do {
                try self.recorder.observe(meeting: nil, rows: [], at: Date())
                self.timer?.cancel()
                DispatchQueue.main.async { NSApp.terminate(nil) }
            } catch { self.showError("Could not save captions; the app is still running. " + error.localizedDescription) }
        }
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Zoom Caption Saver"
            alert.informativeText = message
            alert.runModal()
        }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
