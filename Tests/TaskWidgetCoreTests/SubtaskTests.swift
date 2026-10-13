import XCTest
@testable import TaskWidgetCore

final class SubtaskTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    let noTags = TagConfig(groups: [], sortGroupId: nil)

    func testOldJSONWithoutSubtasksDecodes() throws {
        let json = #"[{"id":"\#(UUID().uuidString)","title":"옛","done":false,"createdAt":"2026-10-01T00:00:00Z"}]"#
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        let t = try d.decode([Todo].self, from: Data(json.utf8))
        XCTAssertEqual(t[0].subtasks, [])
    }

    func testRoundTrip() throws {
        let todo = Todo(title: "a", createdAt: Date(timeIntervalSince1970: 1_800_000_000), subtasks: [Subtask(title: "x", done: true, dueDate: "2026-10-02"), Subtask(title: "y")])
        let back = try TodoStore.decoder.decode([Todo].self, from: TodoStore.encoder.encode([todo]))
        XCTAssertEqual(back, [todo])
    }

    func testCompleteParentCascadesButUncompleteDoesNot() {
        var t = Todo(title: "a", subtasks: [Subtask(title: "x"), Subtask(title: "y", done: true)])
        t.toggleDone()
        XCTAssertTrue(t.done)
        XCTAssertTrue(t.subtasks.allSatisfy(\.done))
        t.subtasks[0].done = false
        t.toggleDone()
        XCTAssertFalse(t.done)
        XCTAssertNil(t.completedAt)
        XCTAssertEqual(t.subtasks.map(\.done), [false, true], "되돌려도 하위는 그대로")
    }

    func testProgress() {
        let t = Todo(title: "a", subtasks: [Subtask(title: "x", done: true), Subtask(title: "y"), Subtask(title: "z")])
        XCTAssertEqual(t.subtaskProgress.done, 1)
        XCTAssertEqual(t.subtaskProgress.total, 3)
        XCTAssertFalse(t.done, "하위가 모두 끝나도 상위는 자동 완료 아님")
    }

    func testUrgentCountIncludesSubtasks() {
        let now = DayKey.date(from: "2026-10-02", calendar: cal)!
        let todos = [
            Todo(title: "a", dueDate: "2026-10-02", subtasks: [
                Subtask(title: "overdue", dueDate: "2026-10-01"),
                Subtask(title: "done", done: true, dueDate: "2026-10-01"),
                Subtask(title: "later", dueDate: "2026-10-09"),
                Subtask(title: "none")]),
            Todo(title: "b", done: true, subtasks: [Subtask(title: "x", dueDate: "2026-10-01")]),
        ]
        XCTAssertEqual(DueBadge.urgentCount(todos: todos, now: now, calendar: cal), 2)
    }

    func testInboxSubParseAndImport() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let r = TodoInbox.runCLI(args: ["--title", "큰 일", "--sub", " 하나 ", "--sub", "둘", "--sub", "  "],
                                 inboxDir: dir, config: noTags)
        XCTAssertEqual(r.code, 0)
        var imported: [Todo] = []
        TodoInbox.importPending(inboxDir: dir, config: noTags) { imported = $0 }
        XCTAssertEqual(imported.first?.subtasks.map(\.title), ["하나", "둘"])
    }
}
