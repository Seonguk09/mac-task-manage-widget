import AppKit
import SwiftUI
import TaskWidgetCore

private struct AtmAccentKey: EnvironmentKey { static let defaultValue = Color.accentColor }
private struct AtmThemedKey: EnvironmentKey { static let defaultValue = false }
private struct AtmBackgroundKey: EnvironmentKey { static let defaultValue: Color? = nil }

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
    /// 테마 배경색 (팝오버 배경을 패널과 맞출 때). 테마를 안 쓰면 nil → 시스템 팝오버 배경.
    var atmBackground: Color? {
        get { self[AtmBackgroundKey.self] }
        set { self[AtmBackgroundKey.self] = newValue }
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
            content.environment(\.atmAccent, accent).environment(\.atmThemed, true)
                .environment(\.atmBackground, Color(hex: c.background)).tint(accent)
        } else {
            content
        }
    }
}

extension View {
    func themedPanel() -> some View { modifier(ThemedPanel()) }
}

/// 팝오버 배경을 패널 테마 배경과 맞춘다 (기본은 회색 시스템 팝오버).
struct ThemedPopover: ViewModifier {
    @Environment(\.atmBackground) private var bg
    func body(content: Content) -> some View {
        if let bg { content.presentationBackground(bg) } else { content }
    }
}

extension View {
    func themedPopover() -> some View { modifier(ThemedPopover()) }
}

/// 할 일 추가칸과 같은 모양의 입력칸: 옅은 바탕, 선택하면 테마 강조색 테두리. 팝오버·패널 안 입력칸 공용.
struct ThemedTextField: View {
    let prompt: String
    @Binding var text: String
    var secure = false
    var autofocus = false
    var onSubmit: () -> Void = {}
    @Environment(\.fontScale) private var scale
    @Environment(\.atmAccent) private var accent
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if secure {
                SecureField(prompt, text: $text).textContentType(.oneTimeCode)
            } else {
                TextField(prompt, text: $text)
            }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 12 * scale))
        .focused($focused)
        .onSubmit(onSubmit)
        .padding(.horizontal, 7).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 6)
            .strokeBorder(focused ? accent : Color.primary.opacity(0.12), lineWidth: focused ? 1.5 : 0.5))
        .onAppear { if autofocus { DispatchQueue.main.async { focused = true } } }
    }
}

/// 팝오버 아래 버튼 줄: 취소(흐림) + 주 버튼(강조색). 주 버튼은 ↩ 로도 눌린다.
struct PopoverButtons: View {
    let primary: String
    var busy = false
    let cancel: () -> Void
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Spacer()
            Button(action: cancel) { AccentChip(icon: "xmark", text: "취소", style: .plain) }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            Button(action: submit) { AccentChip(icon: "checkmark", text: primary, style: .solid) }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(busy)
        }
    }
}
