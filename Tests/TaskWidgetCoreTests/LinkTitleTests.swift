import XCTest
@testable import TaskWidgetCore

final class LinkTitleTests: XCTestCase {
    func testParseEntitiesAndWhitespace() {
        let html = "<html><HEAD><TITLE lang=\"ko\">\n  A &amp; B  &lt;c&gt;\n &quot;d&quot; &#39;e&#39; &#65;  </TITLE></HEAD>"
        XCTAssertEqual(LinkTitle.parse(html: html), "A & B <c> \"d\" 'e' A")
    }

    func testParseDoesNotDoubleDecodeAmp() {
        XCTAssertEqual(LinkTitle.parse(html: "<title>&amp;lt;</title>"), "&lt;")
    }

    func testParseMissingOrEmpty() {
        XCTAssertNil(LinkTitle.parse(html: "<html></html>"))
        XCTAssertNil(LinkTitle.parse(html: "<title>  </title>"))
    }

    func testNormalize() {
        XCTAssertEqual(LinkTitle.normalize("example.com/x")?.absoluteString, "https://example.com/x")
        XCTAssertEqual(LinkTitle.normalize(" http://a.io ")?.absoluteString, "http://a.io")
        XCTAssertNil(LinkTitle.normalize("not a url"))
        XCTAssertNil(LinkTitle.normalize(""))
        XCTAssertNil(LinkTitle.normalize("ftp://a.io"))
        XCTAssertNil(LinkTitle.normalize("nodot"))
    }
}
