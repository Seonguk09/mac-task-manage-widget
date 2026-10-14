import XCTest
@testable import TaskWidgetCore

final class ConfluenceClientTests: XCTestCase {
    let base = URL(string: "https://example.atlassian.net")!

    func fixture() throws -> Data {
        let url = Bundle.module.url(forResource: "confluence-starred", withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }

    func testDecodeFixture() throws {
        let pages = try ConfluenceClient.decode(try fixture(), base: base)
        XCTAssertEqual(pages.map(\.title), ["배포 가이드", "온보딩"])
        XCTAssertEqual(pages.map(\.spaceKey), ["DEV", "HR"])
        XCTAssertEqual(pages[0].url.absoluteString, "https://example.atlassian.net/wiki/spaces/DEV/pages/1001/Deploy+Guide")
        XCTAssertNotNil(pages[0].updated)
        XCTAssertNil(pages[1].updated)
    }

    func testMissingBaseFallsBackToWiki() throws {
        let json = #"{"results":[{"id":"1","title":"t","_links":{"webui":"/x"}}]}"#
        let pages = try ConfluenceClient.decode(Data(json.utf8), base: base)
        XCTAssertEqual(pages[0].url.absoluteString, "https://example.atlassian.net/wiki/x")
        XCTAssertEqual(pages[0].spaceKey, "")
    }

    func testGarbageThrows() {
        XCTAssertThrowsError(try ConfluenceClient.decode(Data("nope".utf8), base: base))
    }
}
