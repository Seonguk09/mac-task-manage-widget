import XCTest
@testable import TaskWidgetCore

final class NoteStoreTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func testMissingFileIsEmpty() {
        XCTAssertEqual(NoteStore(fileURL: dir.appendingPathComponent("notes.json")).load(), NotesData())
    }

    func testRoundTripAnd0600() throws {
        let url = dir.appendingPathComponent("notes.json")
        let store = NoteStore(fileURL: url)
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let data = NotesData(
            memos: [Memo(title: "a", body: "b\nc", pinned: true, createdAt: t, updatedAt: t.addingTimeInterval(100)),
                    Memo(title: "s", sealed: "AAAA", createdAt: t, updatedAt: t)],
            links: [SavedLink(title: "t", url: "https://a.io", createdAt: t)],
            lock: NoteLock(salt: "s", iterations: 1000, verifier: "v"))
        try store.save(data)
        try store.save(data)   // 덮어쓰기 경로
        XCTAssertEqual(store.load(), data)
        let perm = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(perm, 0o600)
    }

    func testCorruptIsBackedUp() throws {
        let url = dir.appendingPathComponent("notes.json")
        try Data("{not json".utf8).write(to: url)
        XCTAssertEqual(NoteStore(fileURL: url).load(), NotesData())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("notes.corrupt-") })
    }

    func testLenientDecodeOfEmptyObject() throws {
        let d = try NoteStore.decoder.decode(NotesData.self, from: Data("{}".utf8))
        XCTAssertEqual(d, NotesData())
        let m = try NoteStore.decoder.decode(Memo.self, from: Data(#"{"title":"x"}"#.utf8))
        XCTAssertEqual(m.title, "x")
        XCTAssertEqual(m.body, "")
        XCTAssertFalse(m.locked)
    }

    func testPreviewAndLocked() {
        XCTAssertEqual(Memo(title: "t", body: "\n  \n  첫 줄 \n둘째").preview, "첫 줄")
        XCTAssertNil(Memo(title: "t", body: "").preview)
        XCTAssertNil(Memo(title: "t", sealed: "x").preview)
        XCTAssertTrue(Memo(title: "t", sealed: "x").locked)
    }

    func testOrderPinnedThenUpdated() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let old = Memo(title: "old", updatedAt: t)
        let new = Memo(title: "new", updatedAt: t.addingTimeInterval(100))
        let pinnedOld = Memo(title: "pinned", pinned: true, updatedAt: t.addingTimeInterval(-100))
        XCTAssertEqual(NotesOrder.memos([old, new, pinnedOld]).map(\.title), ["pinned", "new", "old"])
    }
}
