import XCTest
@testable import TaskWidgetCore

final class TshProfileRepairTests: XCTestCase {
    func testRemovesOnlyEmptyFiles() throws {
        let fm = FileManager.default
        let keys = fm.temporaryDirectory.appendingPathComponent("tsh-\(UUID().uuidString)/keys")
        let db = keys.appendingPathComponent("proxy/user-db/c")
        try fm.createDirectory(at: db, withIntermediateDirectories: true)
        try Data().write(to: db.appendingPathComponent("a-x509.pem"))
        try Data("-----BEGIN CERTIFICATE-----".utf8).write(to: db.appendingPathComponent("b-x509.pem"))
        defer { try? fm.removeItem(at: keys.deletingLastPathComponent()) }

        XCTAssertEqual(TshProfileRepair.removeEmptyFiles(in: keys), ["proxy/user-db/c/a-x509.pem"])
        XCTAssertFalse(fm.fileExists(atPath: db.appendingPathComponent("a-x509.pem").path))
        XCTAssertTrue(fm.fileExists(atPath: db.appendingPathComponent("b-x509.pem").path))
        XCTAssertEqual(TshProfileRepair.removeEmptyFiles(in: keys), [])
    }

    func testMissingDirIsNoop() {
        XCTAssertEqual(TshProfileRepair.removeEmptyFiles(in: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")), [])
    }
}
