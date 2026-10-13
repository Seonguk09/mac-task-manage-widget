import XCTest
@testable import TaskWidgetCore

final class ThemePaletteTests: XCTestCase {
    func testHexParse() {
        let c = HexColor.rgb("#FF8000")!
        XCTAssertEqual(c.r, 1); XCTAssertEqual(c.g, 128.0 / 255, accuracy: 1e-9); XCTAssertEqual(c.b, 0)
        XCTAssertNotNil(HexColor.rgb("0A84FF"))
        XCTAssertNil(HexColor.rgb("#FFF"))
        XCTAssertNil(HexColor.rgb("#GGGGGG"))
    }

    func testLuminanceAndIsDark() {
        XCTAssertEqual(ThemePalette.luminance("#FFFFFF"), 1, accuracy: 1e-9)
        XCTAssertEqual(ThemePalette.luminance("#000000"), 0)
        XCTAssertTrue(ThemeColors(background: "#161B2E", accent: "#7C9CFF").isDark)
        XCTAssertFalse(ThemeColors(background: "#F6F1EA", accent: "#B5832F").isDark)
    }

    func testPresetLookup() {
        XCTAssertEqual(ThemePalette.presets.count, 13)
        XCTAssertEqual(Set(ThemePalette.presets.map(\.id)).count, 13)
        let r = ThemePalette.resolve(id: "ocean", customBackground: "#000000", customAccent: "#FFFFFF")
        XCTAssertEqual(r, ThemeColors(background: "#0F2A3A", accent: "#3CC8E0"))
    }

    func testCustomResolutionAndUnknownID() {
        XCTAssertEqual(ThemePalette.resolve(id: "custom", customBackground: "#111111", customAccent: "#EEEEEE"),
                       ThemeColors(background: "#111111", accent: "#EEEEEE"))
        XCTAssertNil(ThemePalette.resolve(id: "default", customBackground: "#111111", customAccent: "#EEEEEE"))
        XCTAssertNil(ThemePalette.resolve(id: "nope", customBackground: "#111111", customAccent: "#EEEEEE"))
    }

    func testSettingsKeys() {
        let name = "ThemeTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        defer { d.removePersistentDomain(forName: name) }
        let s = Settings(defaults: d)
        XCTAssertNil(s.themeColors)
        s.themePreset = "custom"
        XCTAssertEqual(s.themeColors, ThemeColors(background: "#2B2D31", accent: "#0A84FF"))
    }

    func testPresetsAreVisible() {
        for p in ThemePalette.presets.compactMap(\.colors) { XCTAssertFalse(p.lowContrast, p.background) }
    }

    func testSwatchesWellFormed() {
        let all = ThemePalette.lightBackgrounds + ThemePalette.darkBackgrounds + ThemePalette.accents
        XCTAssertEqual(all.count, 28)
        for h in all { XCTAssertNotNil(HexColor.rgb(h), h) }
        XCTAssertTrue(ThemePalette.lightBackgrounds.allSatisfy { !ThemeColors(background: $0, accent: "#000000").isDark })
        XCTAssertTrue(ThemePalette.darkBackgrounds.allSatisfy { ThemeColors(background: $0, accent: "#000000").isDark })
    }
}
