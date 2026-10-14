import XCTest
import CryptoKit
@testable import TaskWidgetCore

final class NoteCryptoTests: XCTestCase {
    let it = 1000   // 테스트는 반복 횟수를 낮춰 빠르게

    func testSealOpenRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let sealed = try NoteCrypto.seal("비밀 메모\n두 번째 줄", key: key)
        XCTAssertFalse(sealed.contains("비밀"))
        XCTAssertEqual(try NoteCrypto.open(sealed, key: key), "비밀 메모\n두 번째 줄")
    }

    func testOpenWithOtherKeyThrows() throws {
        let sealed = try NoteCrypto.seal("x", key: SymmetricKey(size: .bits256))
        XCTAssertThrowsError(try NoteCrypto.open(sealed, key: SymmetricKey(size: .bits256)))
    }

    func testMakeLockThenUnlock() throws {
        let (lock, key) = try NoteCrypto.makeLock(password: "pw1234", iterations: it)
        let again = try NoteCrypto.unlock(password: "pw1234", lock: lock)
        XCTAssertEqual(NoteCrypto.rawKey(key), NoteCrypto.rawKey(again))
        let sealed = try NoteCrypto.seal("hello", key: key)
        XCTAssertEqual(try NoteCrypto.open(sealed, key: again), "hello")
    }

    func testWrongPasswordThrows() throws {
        let (lock, _) = try NoteCrypto.makeLock(password: "pw1234", iterations: it)
        XCTAssertThrowsError(try NoteCrypto.unlock(password: "nope", lock: lock)) {
            XCTAssertEqual($0 as? NoteCryptoError, .wrongPassword)
        }
    }

    func testDifferentSaltDifferentKey() {
        let s1 = Data(repeating: 1, count: 16), s2 = Data(repeating: 2, count: 16)
        let a = try! NoteCrypto.deriveKey(password: "same", salt: s1, iterations: it)
        let b = try! NoteCrypto.deriveKey(password: "same", salt: s2, iterations: it)
        XCTAssertNotEqual(NoteCrypto.rawKey(a), NoteCrypto.rawKey(b))
        XCTAssertEqual(NoteCrypto.rawKey(a), NoteCrypto.rawKey(try! NoteCrypto.deriveKey(password: "same", salt: s1, iterations: it)))
    }

    func testRawKeyRoundTrip() {
        let k = SymmetricKey(size: .bits256)
        XCTAssertEqual(NoteCrypto.rawKey(NoteCrypto.key(fromRaw: NoteCrypto.rawKey(k))), NoteCrypto.rawKey(k))
    }

    func testPBKDF2KnownVector() {
        // RFC 7914 §11 (PBKDF2-HMAC-SHA256, "passwd"/"salt", c=1) 앞 32바이트
        let k = try! NoteCrypto.deriveKey(password: "passwd", salt: Data("salt".utf8), iterations: 1)
        let hex = NoteCrypto.rawKey(k).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc")
    }

    func testEmptyPasswordAndBadIterationsThrow() throws {
        let salt = Data(repeating: 1, count: 16)
        XCTAssertThrowsError(try NoteCrypto.deriveKey(password: "", salt: salt, iterations: it))
        XCTAssertThrowsError(try NoteCrypto.deriveKey(password: "x", salt: salt, iterations: 0))
        XCTAssertThrowsError(try NoteCrypto.deriveKey(password: "x", salt: salt, iterations: -5))
        XCTAssertThrowsError(try NoteCrypto.deriveKey(password: "x", salt: salt, iterations: Int.max))
        let (lock, _) = try NoteCrypto.makeLock(password: "pw1234", iterations: it)
        var bad = lock; bad.iterations = 0
        XCTAssertThrowsError(try NoteCrypto.unlock(password: "pw1234", lock: bad))
        XCTAssertThrowsError(try NoteCrypto.unlock(password: "", lock: lock))
    }
}
