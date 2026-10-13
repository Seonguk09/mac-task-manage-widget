import Foundation

/// 켜 둔 터널을 어떻게 살릴지 정하는 순수 판단. 실제 실행은 TeleportManager 가 한다.
/// 포기는 없다: 실패하면 간격을 늘려(최대 5분) 계속 다시 시도한다.
public struct TeleportWatchdogPolicy: Equatable {
    public static let maxBackoff: TimeInterval = 300

    public var relogin = false
    public var restart: [String] = []
    /// 재시도 대기 중인 터널과 남은 초.
    public var waiting: [String: TimeInterval] = [:]

    /// 연속 `failures` 번째 실패 뒤 다음 시도까지 기다릴 시간: interval × 2^(n-1), 최대 5분.
    public static func backoff(failures: Int, interval: TimeInterval) -> TimeInterval {
        guard failures > 0 else { return 0 }
        return min(interval * pow(2, Double(min(failures, 20) - 1)), maxBackoff)
    }

    public static func waitText(_ seconds: TimeInterval) -> String {
        seconds < 60 ? "\(max(1, Int(seconds.rounded(.up))))초 후" : "\(Int((seconds / 60).rounded(.up)))분 후"
    }

    /// - healthy: 포트가 열려 있는 터널.
    /// - retryAt: 실패한 터널의 다음 시도 시각.
    public static func decide(wanted: [String], running: Set<String>, healthy: Set<String>,
                              retryAt: [String: Date], loggedIn: Bool, now: Date = Date()) -> TeleportWatchdogPolicy {
        var p = TeleportWatchdogPolicy()
        for n in wanted {
            // 재로그인하면 기존 터널의 인증서가 낡았으므로 모두 재시작
            guard !loggedIn || !running.contains(n) || !healthy.contains(n) else { continue }
            if let at = retryAt[n], at > now { p.waiting[n] = at.timeIntervalSince(now); continue }
            p.restart.append(n)
        }
        p.relogin = !loggedIn && !p.restart.isEmpty
        return p
    }
}
