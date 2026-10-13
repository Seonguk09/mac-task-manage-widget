import AppKit
import XCTest
@testable import TaskWidgetCore

final class HotKeySpecTests: XCTestCase {
    func testDefaultIsCtrlOptSpace() {
        XCTAssertEqual(HotKeySpec.default.displayString, "⌃⌥Space")
        XCTAssertTrue(HotKeySpec.default.isValid)
    }

    func testDisplayString() {
        XCTAssertEqual(HotKeySpec(keyCode: 40, modifiers: HotKeySpec.cmd | HotKeySpec.shift).displayString, "⇧⌘K")
        XCTAssertEqual(HotKeySpec(keyCode: 122, modifiers: HotKeySpec.cmd).displayString, "⌘F1")
        XCTAssertEqual(HotKeySpec(keyCode: 123, modifiers: HotKeySpec.control).displayString, "⌃←")
        XCTAssertEqual(HotKeySpec(keyCode: 18, modifiers: HotKeySpec.option).displayString, "⌥1")
        XCTAssertEqual(HotKeySpec(keyCode: 200, modifiers: HotKeySpec.cmd).displayString, "⌘Key200")
        let all = HotKeySpec.control | HotKeySpec.option | HotKeySpec.shift | HotKeySpec.cmd
        XCTAssertEqual(HotKeySpec(keyCode: 36, modifiers: all).displayString, "⌃⌥⇧⌘Return")
    }

    func testValidation() {
        XCTAssertFalse(HotKeySpec(keyCode: 40, modifiers: HotKeySpec.shift).isValid)
        XCTAssertFalse(HotKeySpec(keyCode: 40, modifiers: 0).isValid)
        XCTAssertFalse(HotKeySpec(keyCode: 53, modifiers: HotKeySpec.cmd).isValid)
        XCTAssertTrue(HotKeySpec(keyCode: 40, modifiers: HotKeySpec.option).isValid)
    }

    func testCarbonModifiers() {
        XCTAssertEqual(HotKeySpec.carbonModifiers([.command, .shift]), HotKeySpec.cmd | HotKeySpec.shift)
        XCTAssertEqual(HotKeySpec.carbonModifiers([.control, .option]), HotKeySpec.control | HotKeySpec.option)
        XCTAssertEqual(HotKeySpec.carbonModifiers([.capsLock]), 0)
    }

    func testPersistence() {
        let suite = "hotkey-\(UUID().uuidString)"
        let s = Settings(defaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(s.globalHotKey, .default)
        let spec = HotKeySpec(keyCode: 40, modifiers: HotKeySpec.cmd | HotKeySpec.shift)
        s.globalHotKey = spec
        XCTAssertEqual(s.globalHotKey, spec)
    }
}
