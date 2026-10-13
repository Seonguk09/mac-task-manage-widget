import AppKit
import SwiftUI
import TaskWidgetCore

private struct AtmAccentKey: EnvironmentKey { static let defaultValue = Color.accentColor }
private struct AtmThemedKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// 패널 강조색. 테마 색을 쓰지 않으면 시스템 강조색.
    var atmAccent: Color {
        get { self[AtmAccentKey.self] }
        set { self[AtmAccentKey.self] = newValue }
    }
    /// 테마 색 사용 중인지 (NSSegmentedControl 처럼 환경 tint 를 못 받는 AppKit 뷰용).
    var atmThemed: Bool {
        get { self[AtmThemedKey.self] }
        set { self[AtmThemedKey.self] = newValue }
    }
}

/// 패널 루트에 붙여 강조색을 주입한다. 설정이 바뀌면 AppStorage 로 바로 갱신된다.
struct ThemedPanel: ViewModifier {
    @AppStorage(SettingsKey.themePreset) private var preset = "default"
    @AppStorage(SettingsKey.customBackground) private var customBackground = ThemePalette.defaultBackground
    @AppStorage(SettingsKey.customAccent) private var customAccent = ThemePalette.defaultAccent

    @ViewBuilder
    func body(content: Content) -> some View {
        if let c = ThemePalette.resolve(id: preset, customBackground: customBackground, customAccent: customAccent) {
            let accent = Color(hex: c.accent)
            content.environment(\.atmAccent, accent).environment(\.atmThemed, true).tint(accent)
        } else {
            content
        }
    }
}

extension View {
    func themedPanel() -> some View { modifier(ThemedPanel()) }
}
