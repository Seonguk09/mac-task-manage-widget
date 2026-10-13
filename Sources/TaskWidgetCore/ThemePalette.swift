import Foundation

/// 패널 배경·강조색 한 쌍 (#RRGGBB).
public struct ThemeColors: Equatable {
    public let background: String
    public let accent: String
    public init(background: String, accent: String) { self.background = background; self.accent = accent }

    /// 배경이 어두운 톤인가 (글자색을 밝게 해야 하는지).
    public var isDark: Bool { ThemePalette.luminance(background) < 0.5 }
    /// 강조색과 배경이 비슷해 잘 안 보이는가.
    public var lowContrast: Bool { abs(ThemePalette.luminance(background) - ThemePalette.luminance(accent)) < ThemePalette.minContrast }
}

public struct ThemePreset: Equatable, Identifiable {
    public let id: String
    public let name: String
    /// nil = 기본(시스템/라이트/다크 테마를 따름)
    public let colors: ThemeColors?
}

public enum ThemePalette {
    public static let minContrast = 0.18
    public static let customID = "custom"
    public static let defaultBackground = "#2B2D31"
    public static let defaultAccent = "#0A84FF"

    public static let presets: [ThemePreset] = [
        ThemePreset(id: "default", name: "기본", colors: nil),
        p("midnight", "미드나잇", "#161B2E", "#7C9CFF"),
        p("ocean", "오션", "#0F2A3A", "#3CC8E0"),
        p("forest", "포레스트", "#16271F", "#4CC38A"),
        p("mocha", "모카", "#2E2620", "#E0A066"),
        p("rose", "로즈", "#33212A", "#F07BA6"),
        p("graphite", "그라파이트", "#1A1A1C", "#BFBFC4"),
        p("lavender", "라벤더", "#ECE8F7", "#7F5AD6"),
        p("peach", "피치", "#FBEDE6", "#E2683C"),
        p("mint", "민트", "#E6F4EE", "#1E9C74"),
        p("sky", "스카이", "#E7F0FA", "#2F7DD3"),
        p("sand", "샌드", "#F6F1EA", "#B5832F"),
        p("paper", "페이퍼", "#FFFFFF", "#0A84FF"),
    ]
    private static func p(_ id: String, _ name: String, _ bg: String, _ ac: String) -> ThemePreset {
        ThemePreset(id: id, name: name, colors: ThemeColors(background: bg, accent: ac))
    }

    public static let lightBackgrounds = ["#FFFFFF", "#F2F2F4", "#F6F1EA", "#EEF2F7", "#ECE8F7",
                                          "#E6F4EE", "#FBEDE6", "#FFF6D9", "#FCE9EF", "#E7F0FA"]
    public static let darkBackgrounds = ["#2B2D31", "#1A1A1C", "#161B2E", "#0F2A3A", "#16271F",
                                         "#2E2620", "#2A1F33", "#33212A", "#2C2A1A", "#1E2B2B"]
    public static let accents = ["#0A84FF", "#7F77DD", "#D4537E", "#E8833A", "#1D9E75", "#14A3B8", "#C9A227", "#8E8E93"]

    /// 감각 밝기 0...1 (감마 값 기준 가중합). 잘못된 hex 는 0.
    public static func luminance(_ hex: String) -> Double {
        guard let c = HexColor.rgb(hex) else { return 0 }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    /// 저장된 프리셋 id 로 색을 구한다. 기본·모르는 id 는 nil, "custom" 은 직접 고른 쌍.
    public static func resolve(id: String, customBackground: String, customAccent: String) -> ThemeColors? {
        if id == customID { return ThemeColors(background: customBackground, accent: customAccent) }
        return presets.first { $0.id == id }?.colors
    }
}
