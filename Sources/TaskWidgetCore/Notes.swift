import Foundation

public struct Memo: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    /// 잠긴 메모는 "" (평문을 디스크에 남기지 않는다).
    public var body: String
    /// 잠겼을 때 body 를 AES-GCM 으로 봉인한 base64(nonce+ct+tag). 안 잠겼으면 nil.
    public var sealed: String?
    public var pinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String, body: String = "", sealed: String? = nil, pinned: Bool = false,
                createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id; self.title = title; self.body = body; self.sealed = sealed
        self.pinned = pinned; self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    // 나중에 필드가 늘어도 옛 파일이 깨지지 않게 빠진 키는 기본값.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        sealed = try c.decodeIfPresent(String.self, forKey: .sealed)
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    public var locked: Bool { sealed != nil }

    /// 본문 첫 비어있지 않은 줄. 잠겼거나 비었으면 nil.
    public var preview: String? {
        guard !locked else { return nil }
        return Self.firstLine(body)
    }

    public static func firstLine(_ text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { return t }
        }
        return nil
    }
}

public struct SavedLink: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var url: String
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, url: String, createdAt: Date = Date()) {
        self.id = id; self.title = title; self.url = url; self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? url
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

public struct NoteLock: Codable, Equatable {
    /// base64 16바이트
    public var salt: String
    public var iterations: Int
    /// 고정 문자열을 열쇠로 봉인한 base64. 비밀번호 확인용.
    public var verifier: String

    public init(salt: String, iterations: Int, verifier: String) {
        self.salt = salt; self.iterations = iterations; self.verifier = verifier
    }
}

public struct NotesData: Codable, Equatable {
    public var memos: [Memo] = []
    public var links: [SavedLink] = []
    public var lock: NoteLock?

    public init(memos: [Memo] = [], links: [SavedLink] = [], lock: NoteLock? = nil) {
        self.memos = memos; self.links = links; self.lock = lock
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        memos = try c.decodeIfPresent([Memo].self, forKey: .memos) ?? []
        links = try c.decodeIfPresent([SavedLink].self, forKey: .links) ?? []
        lock = try c.decodeIfPresent(NoteLock.self, forKey: .lock)
    }
}

public enum NotesOrder {
    /// 고정된 메모 먼저, 그 안에서 최근 수정 순.
    public static func memos(_ list: [Memo]) -> [Memo] {
        list.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.updatedAt > b.updatedAt
        }
    }
}

public struct NoteStore {
    public let fileURL: URL

    public init(fileURL: URL = Paths.notesFile) {
        self.fileURL = fileURL
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// 파일 없으면 빈 데이터. 파싱 실패면 notes.corrupt-<ts>.json 으로 옮기고 빈 데이터.
    public func load() -> NotesData {
        guard let data = try? Data(contentsOf: fileURL) else { return NotesData() }
        if let d = try? Self.decoder.decode(NotesData.self, from: data) { return d }
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent("notes.corrupt-\(stamp).json")
        try? FileManager.default.moveItem(at: fileURL, to: backup)
        return NotesData()
    }

    /// 메모 내용이 들어 있으니 내 계정만 읽게 0600. 임시 파일을 0600 으로 만들어 바꿔치기해 노출 순간을 없앤다.
    public func save(_ data: NotesData) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = try Self.encoder.encode(data)
        let tmp = fileURL.appendingPathExtension("tmp")
        guard fm.createFile(atPath: tmp.path, contents: bytes, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        if fm.fileExists(atPath: fileURL.path) {
            _ = try fm.replaceItemAt(fileURL, withItemAt: tmp)
        } else {
            try fm.moveItem(at: tmp, to: fileURL)
        }
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
