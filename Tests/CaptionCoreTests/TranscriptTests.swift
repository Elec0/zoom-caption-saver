import XCTest
@testable import CaptionCore

final class TranscriptTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1000)

    func testCaptionRevisionsReplaceEarlierTextAndKeepFirstTimestamp() {
        var transcript = Transcript()
        XCTAssertTrue(transcript.observe([CaptionRow(id: "row-1", text: "Alex: We need a cat")], at: start))
        XCTAssertTrue(transcript.observe([CaptionRow(id: "row-1", text: "Alex: We need a caption recorder.")],
                                         at: start.addingTimeInterval(2)))
        XCTAssertEqual(transcript.entries, [TranscriptEntry(firstSeen: start,
                                                           text: "Alex: We need a caption recorder.")])
    }

    func testRepeatedPollDoesNotDuplicateCaption() {
        var transcript = Transcript()
        let rows = [CaptionRow(id: "row-1", text: "Alex: Hello.")]
        XCTAssertTrue(transcript.observe(rows, at: start))
        XCTAssertFalse(transcript.observe(rows, at: start.addingTimeInterval(1)))
        XCTAssertEqual(transcript.entries.count, 1)
    }

    func testDifferentRowsCanContainTheSameWords() {
        var transcript = Transcript()
        _ = transcript.observe([CaptionRow(id: "row-1", text: "Alex: Yes.")], at: start)
        _ = transcript.observe([CaptionRow(id: "row-1", text: "Alex: Yes."),
                                CaptionRow(id: "row-2", text: "Alex: Yes.")], at: start.addingTimeInterval(1))
        XCTAssertEqual(transcript.entries.map(\.text), ["Alex: Yes.", "Alex: Yes."])
    }

    func testCaptionDisappearingDoesNotEraseSavedText() {
        var transcript = Transcript()
        _ = transcript.observe([CaptionRow(id: "row-1", text: "Alex: Keep this.")], at: start)
        XCTAssertFalse(transcript.observe([], at: start.addingTimeInterval(1)))
        XCTAssertEqual(transcript.entries.map(\.text), ["Alex: Keep this."])
    }

    func testReusedRowAfterDisappearingDoesNotOverwriteOldCaption() {
        var transcript = Transcript()
        _ = transcript.observe([CaptionRow(id: "row-1", text: "Alex: First.")], at: start)
        _ = transcript.observe([], at: start.addingTimeInterval(1))
        _ = transcript.observe([CaptionRow(id: "row-1", text: "Blair: Second.")], at: start.addingTimeInterval(2))
        XCTAssertEqual(transcript.entries.map(\.text), ["Alex: First.", "Blair: Second."])
    }
}
