import Foundation

public enum LinkTitle {
    /// "example.com/x" → https URL. 스킴이 없으면 https:// 를 붙이고, http/https 가 아니거나 호스트가 없으면 nil.
    public static func normalize(_ input: String) -> URL? {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.contains(where: \.isWhitespace) else { return nil }
        let s = t.contains("://") ? t : "https://" + t
        guard let u = URL(string: s), let scheme = u.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = u.host, host.contains(".") || host == "localhost" else { return nil }
        return u
    }

    /// `<title>` 내용. 대소문자 무시, HTML 엔티티 해독, 공백 정리. 없거나 비면 nil.
    public static func parse(html: String) -> String? {
        guard let open = html.range(of: "<title[^>]*>", options: [.regularExpression, .caseInsensitive]),
              let close = html.range(of: "</title>", options: .caseInsensitive, range: open.upperBound..<html.endIndex)
        else { return nil }
        let raw = decodeEntities(String(html[open.upperBound..<close.lowerBound]))
        let t = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return t.isEmpty ? nil : t
    }

    static func decodeEntities(_ s: String) -> String {
        var out = s
        // &amp; 는 마지막에: 먼저 풀면 "&amp;lt;" 가 "<" 로 두 번 풀린다.
        for (k, v) in ["&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"] {
            out = out.replacingOccurrences(of: k, with: v)
        }
        let re = try! NSRegularExpression(pattern: "&#(\\d+);")
        for m in re.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed() {
            guard let r = Range(m.range, in: out), let n = Range(m.range(at: 1), in: out),
                  let code = UInt32(out[n]), let sc = Unicode.Scalar(code) else { continue }
            out.replaceSubrange(r, with: String(Character(sc)))
        }
        return out.replacingOccurrences(of: "&amp;", with: "&")
    }

    /// 쿠키 없는 임시 세션으로 최대 512KB 까지만 받아 제목을 읽는다. 실패하면 nil.
    public static func fetch(_ url: URL) async -> String? {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 5
        cfg.timeoutIntervalForResource = 5
        cfg.httpCookieStorage = nil
        cfg.httpShouldSetCookies = false
        let session = URLSession(configuration: cfg)
        defer { session.finishTasksAndInvalidate() }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh) ATM", forHTTPHeaderField: "User-Agent")
        req.setValue("text/html", forHTTPHeaderField: "Accept")
        guard let (bytes, resp) = try? await session.bytes(for: req),
              (resp as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) ?? false else { return nil }
        var data = Data()
        do {
            for try await b in bytes {
                data.append(b)
                if data.count >= 512 * 1024 { break }
            }
        } catch { /* 중간에 끊겨도 받은 만큼으로 시도 */ }
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return parse(html: html)
    }
}
