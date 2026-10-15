import XCTest
@testable import CaptionCore

final class MeetingRecorderTests: XCTestCase {
    var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testDoesNotCreateEmptyTranscriptsWhenWaiting() throws {
        let recorder = MeetingRecorder(directory: directory)
        try recorder.observe(meeting: "one", rows: [], at: Date())
        XCTAssertNil(recorder.currentFile)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }

    func testFileContainsRevisedCaptionWithSpeakerAndTimestamp() throws {
        let recorder = MeetingRecorder(directory: directory)
        let start = Date(timeIntervalSince1970: 1000)
        try recorder.observe(meeting: "one", rows: [CaptionRow(id: "a", text: "Alex: A cat")], at: start)
        try recorder.observe(meeting: "one", rows: [CaptionRow(id: "a", text: "Alex: A caption.")],
                             at: start.addingTimeInterval(1))
        let file = try XCTUnwrap(recorder.currentFile)
        let text = try String(contentsOf: file)
        XCTAssertTrue(text.contains("Alex: A caption."))
        XCTAssertFalse(text.contains("Alex: A cat\n"))
        XCTAssertTrue(text.contains("1970-01-01T00:16:40"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)
    }

    func testNextMeetingGetsASeparateFileAndIndependentHistory() throws {
        let recorder = MeetingRecorder(directory: directory)
        try recorder.observe(meeting: "one", rows: [CaptionRow(id: "a", text: "Alex: First meeting.")], at: Date())
        let first = try XCTUnwrap(recorder.currentFile)
        try recorder.observe(meeting: nil, rows: [], at: Date())
        try recorder.observe(meeting: "two", rows: [CaptionRow(id: "a", text: "Blair: Second meeting.")], at: Date())
        let second = try XCTUnwrap(recorder.currentFile)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(try String(contentsOf: first).contains("First meeting."))
        XCTAssertFalse(try String(contentsOf: second).contains("First meeting."))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 2)
    }

    func testHidingCaptionsKeepsTheSameMeetingFile() throws {
        let recorder = MeetingRecorder(directory: directory)
        try recorder.observe(meeting: "one", rows: [CaptionRow(id: "a", text: "Alex: Hello.")], at: Date())
        let file = try XCTUnwrap(recorder.currentFile)
        try recorder.observe(meeting: "one", rows: [], at: Date())
        try recorder.observe(meeting: "one", rows: [CaptionRow(id: "b", text: "Blair: Back.")], at: Date())
        XCTAssertEqual(file, recorder.currentFile)
        XCTAssertEqual(recorder.transcript.entries.count, 2)
    }
}
