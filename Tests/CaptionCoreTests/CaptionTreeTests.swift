import XCTest
@testable import CaptionCore

final class CaptionTreeTests: XCTestCase {
    func testReadsOnlyTheCaptionTableAndPreservesSpeakerText() {
        let caption = "Aaron Steele (he/him) Hello, we're testing some captions I have two dogs, named Ben and Charlie."
        let root = CaptionNode(id: "window", role: "AXWindow", children: [
            CaptionNode(id: "chat", role: "AXStaticText", value: "Unrelated private chat"),
            CaptionNode(id: "captions", role: "AXTable", label: "Closed caption subtitles", children: [
                CaptionNode(id: "row1", role: "AXRow", children: [
                    CaptionNode(id: "cell", role: "AXCell", children: [
                        CaptionNode(id: "text", role: "AXStaticText", value: caption)
                    ])
                ])
            ])
        ])
        XCTAssertEqual(CaptionTree.rows(in: root), [CaptionRow(id: "row1", text: caption)])
    }

    func testNoCaptionTableMeansNoCapture() {
        let root = CaptionNode(id: "window", role: "AXWindow", children: [
            CaptionNode(id: "chat", role: "AXStaticText", value: "Unrelated private chat")
        ])
        XCTAssertEqual(CaptionTree.rows(in: root), [])
    }
}
