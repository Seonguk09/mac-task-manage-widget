import Foundation
import CryptoKit
import CommonCrypto

public enum NoteCryptoError: Error, Equatable {
    case wrongPassword
    case corrupt
}

/// 메모 잠금용 암호. 비밀번호·열쇠·잠긴 메모의 평문은 로그에 남기지 않는다.
public enum NoteCrypto {
    public static let defaultIterations = 200_000
    /// Touch ID 로 열 때 열쇠 원본을 두는 비밀 저장소 항목.
    public static let touchIDService = "com.lsm0506.TaskWidget.notes"
    public static let touchIDAccount = "key"
    static let maxIterations = 10_000_000
    static let verifierText = "ATM-notes-v1"

    /// PBKDF2-HMAC-SHA256, 32바이트.
    public static func deriveKey(password: String, salt: Data, iterations: Int = defaultIterations) throws -> SymmetricKey {
        // 깨진 notes.json 의 반복 횟수나 빈 비밀번호로 죽지 않게 먼저 거른다.
        guard !password.isEmpty else { throw NoteCryptoError.wrongPassword }
        guard (1...maxIterations).contains(iterations) else { throw NoteCryptoError.corrupt }
        var out = [UInt8](repeating: 0, count: 32)
        let pw = Array(password.utf8)
        let status = pw.withUnsafeBufferPointer { pwp in
            salt.withUnsafeBytes { sp in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                     UnsafeRawPointer(pwp.baseAddress)?.assumingMemoryBound(to: Int8.self), pw.count,
                                     sp.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                                     &out, out.count)
            }
        }
        guard status == Int32(kCCSuccess) else { throw NoteCryptoError.corrupt }
        return SymmetricKey(data: out)
    }

    public static func makeLock(password: String, iterations: Int = defaultIterations) throws -> (NoteLock, SymmetricKey) {
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        let verifier = try seal(verifierText, key: key)
        return (NoteLock(salt: salt.base64EncodedString(), iterations: iterations, verifier: verifier), key)
    }

    public static func unlock(password: String, lock: NoteLock) throws -> SymmetricKey {
        guard let salt = Data(base64Encoded: lock.salt) else { throw NoteCryptoError.corrupt }
        let key = try deriveKey(password: password, salt: salt, iterations: lock.iterations)
        guard (try? open(lock.verifier, key: key)) == verifierText else { throw NoteCryptoError.wrongPassword }
        return key
    }

    /// 열쇠가 이 잠금의 것인지 (Touch ID 저장소에서 읽은 열쇠가 비밀번호 변경 뒤 낡았는지 확인용).
    public static func verify(key: SymmetricKey, lock: NoteLock) -> Bool {
        (try? open(lock.verifier, key: key)) == verifierText
    }

    public static func key(fromRaw data: Data) -> SymmetricKey { SymmetricKey(data: data) }
    public static func rawKey(_ key: SymmetricKey) -> Data { key.withUnsafeBytes { Data($0) } }

    public static func seal(_ text: String, key: SymmetricKey) throws -> String {
        guard let combined = try AES.GCM.seal(Data(text.utf8), using: key).combined else { throw NoteCryptoError.corrupt }
        return combined.base64EncodedString()
    }

    public static func open(_ b64: String, key: SymmetricKey) throws -> String {
        guard let data = Data(base64Encoded: b64) else { throw NoteCryptoError.corrupt }
        let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
        guard let s = String(data: plain, encoding: .utf8) else { throw NoteCryptoError.corrupt }
        return s
    }
}
