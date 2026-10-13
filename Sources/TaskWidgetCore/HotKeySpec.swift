import AppKit

/// 전역 단축키 조합. modifiers 는 Carbon 마스크(cmdKey/optionKey/controlKey/shiftKey).
public struct HotKeySpec: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public static let cmd: UInt32 = 0x100, shift: UInt32 = 0x200, option: UInt32 = 0x800, control: UInt32 = 0x1000
    public static let escKeyCode: UInt32 = 53
    public static let `default` = HotKeySpec(keyCode: 49, modifiers: control | option)  // ⌃⌥Space

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// NSEvent 수정 키 → Carbon 마스크.
    public static func carbonModifiers(_ f: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if f.contains(.command) { m |= cmd }
        if f.contains(.option) { m |= option }
        if f.contains(.control) { m |= control }
        if f.contains(.shift) { m |= shift }
        return m
    }

    /// ⌘·⌃·⌥ 중 하나는 필수(⇧만으로는 일반 타이핑과 충돌), Esc 불가.
    public var isValid: Bool {
        keyCode != Self.escKeyCode && modifiers & (Self.cmd | Self.control | Self.option) != 0
    }

    public var displayString: String {
        var s = ""
        if modifiers & Self.control != 0 { s += "⌃" }
        if modifiers & Self.option != 0 { s += "⌥" }
        if modifiers & Self.shift != 0 { s += "⇧" }
        if modifiers & Self.cmd != 0 { s += "⌘" }
        return s + (Self.keyNames[keyCode] ?? "Key\(keyCode)")
    }

    // ANSI(US 배열) 키코드 표.
    private static let keyNames: [UInt32: String] = {
        var t: [UInt32: String] = [
            49: "Space", 36: "Return", 48: "Tab", 51: "Delete",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            50: "`", 27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/",
        ]
        let keys: [(UInt32, String)] = [
            (0, "A"), (11, "B"), (8, "C"), (2, "D"), (14, "E"), (3, "F"), (5, "G"), (4, "H"), (34, "I"),
            (38, "J"), (40, "K"), (37, "L"), (46, "M"), (45, "N"), (31, "O"), (35, "P"), (12, "Q"), (15, "R"),
            (1, "S"), (17, "T"), (32, "U"), (9, "V"), (13, "W"), (7, "X"), (16, "Y"), (6, "Z"),
            (29, "0"), (18, "1"), (19, "2"), (20, "3"), (21, "4"), (23, "5"), (22, "6"), (26, "7"), (28, "8"), (25, "9"),
        ]
        for (k, n) in keys { t[k] = n }
        for (i, k) in ([122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111] as [UInt32]).enumerated() { t[k] = "F\(i + 1)" }
        return t
    }()
}
