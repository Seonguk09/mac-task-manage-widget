import XCTest
@testable import TaskWidgetCore

final class TeleportWatchdogPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private func decide(running: Set<String> = ["a"], healthy: Set<String> = ["a"],
                        retryAt: [String: Date] = [:], loggedIn: Bool = true) -> TeleportWatchdogPolicy {
        .decide(wanted: ["a"], running: running, healthy: healthy, retryAt: retryAt, loggedIn: loggedIn, now: now)
    }

    func testHealthyNoop() { XCTAssertEqual(decide(), TeleportWatchdogPolicy()) }
    func testDeadProcessRestarts() { XCTAssertEqual(decide(running: [], healthy: []).restart, ["a"]) }
    func testAliveButUnresponsiveRestarts() { XCTAssertEqual(decide(healthy: []).restart, ["a"]) }
    func testNotLoggedInReloginsAndRestartsAll() {
        let p = decide(loggedIn: false)
        XCTAssertTrue(p.relogin)
        XCTAssertEqual(p.restart, ["a"])
    }

    func testBackoffSchedule() {
        let b = { TeleportWatchdogPolicy.backoff(failures: $0, interval: 60) }
        XCTAssertEqual([b(0), b(1), b(2), b(3), b(4), b(5), b(50)], [0, 60, 120, 240, 300, 300, 300])
        XCTAssertEqual(TeleportWatchdogPolicy.backoff(failures: 3, interval: 30), 120)
    }
    func testWaitsUntilRetryTimeThenRetries() {
        let p = decide(running: [], healthy: [], retryAt: ["a": now.addingTimeInterval(90)])
        XCTAssertTrue(p.restart.isEmpty)
        XCTAssertEqual(p.waiting["a"], 90)
        XCTAssertEqual(decide(running: [], healthy: [], retryAt: ["a": now.addingTimeInterval(-1)]).restart, ["a"])
    }
    func testNeverGivesUp() {
        // 아무리 오래 실패해도 시각만 지나면 다시 시도 대상
        XCTAssertEqual(decide(running: [], healthy: [], retryAt: ["a": now]).restart, ["a"])
    }
    func testNoReloginWhileAllWaiting() {
        let p = decide(running: [], healthy: [], retryAt: ["a": now.addingTimeInterval(60)], loggedIn: false)
        XCTAssertFalse(p.relogin)
    }
    func testHealthyIgnoresStaleRetry() {
        // 성공해서 healthy 가 되면 남은 대기 기록은 무시 (Manager 가 지운다)
        XCTAssertEqual(decide(retryAt: ["a": now.addingTimeInterval(60)]), TeleportWatchdogPolicy())
    }
    func testWaitText() {
        XCTAssertEqual(TeleportWatchdogPolicy.waitText(45), "45초 후")
        XCTAssertEqual(TeleportWatchdogPolicy.waitText(61), "2분 후")
        XCTAssertEqual(TeleportWatchdogPolicy.waitText(300), "5분 후")
    }
}
