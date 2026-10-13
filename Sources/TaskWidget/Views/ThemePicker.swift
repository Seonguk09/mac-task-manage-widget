import SwiftUI
import TaskWidgetCore

/// 설정 > 외관의 테마 색: 완성 테마 썸네일 + "직접 조합" (배경·강조색 스와치).
struct ThemeColorPicker: View {
    @AppStorage(SettingsKey.themePreset) private var preset = "default"
    @AppStorage(SettingsKey.customBackground) private var customBackground = ThemePalette.defaultBackground
    @AppStorage(SettingsKey.customAccent) private var customAccent = ThemePalette.defaultAccent

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(ThemePalette.presets) { p in thumbnail(p) }
        }
        DisclosureGroup("직접 조합") {
            VStack(alignment: .leading, spacing: 8) {
                Text("배경").font(.caption).foregroundStyle(.secondary)
                bgRow(ThemePalette.lightBackgrounds)
                bgRow(ThemePalette.darkBackgrounds)
                Text("강조색").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                HStack(spacing: 8) {
                    ForEach(ThemePalette.accents, id: \.self) { hex in
                        let on = preset == ThemePalette.customID && customAccent == hex
                        Circle().fill(Color(hex: hex)).frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(Color.primary, lineWidth: on ? 2 : 0).padding(-3))
                            .contentShape(Circle())
                            .onTapGesture { pickCustom(accent: hex) }
                    }
                }
                if preset == ThemePalette.customID, ThemeColors(background: customBackground, accent: customAccent).lowContrast {
                    Text("강조색이 배경과 비슷해 잘 안 보일 수 있어요").font(.caption).foregroundStyle(.orange)
                }
            }
            .padding(.top, 6)
        }
    }

    private func bgRow(_ list: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(list, id: \.self) { hex in
                let on = preset == ThemePalette.customID && customBackground == hex
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: hex)).frame(width: 26, height: 26)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary, lineWidth: on ? 2 : 0).padding(-3))
                    .contentShape(Rectangle())
                    .onTapGesture { pickCustom(background: hex) }
            }
        }
    }

    /// 스와치를 고르면 "직접 조합"으로 전환한다. 처음 전환할 때는 지금 보이던 색에서 시작한다.
    private func pickCustom(background: String? = nil, accent: String? = nil) {
        if preset != ThemePalette.customID,
           let cur = ThemePalette.resolve(id: preset, customBackground: customBackground, customAccent: customAccent) {
            customBackground = cur.background
            customAccent = cur.accent
        }
        if let background { customBackground = background }
        if let accent { customAccent = accent }
        preset = ThemePalette.customID
    }

    private func thumbnail(_ p: ThemePreset) -> some View {
        let on = preset == p.id
        return VStack(spacing: 4) {
            ZStack {
                if let c = p.colors {
                    RoundedRectangle(cornerRadius: 7).fill(Color(hex: c.background))
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(Color(hex: c.accent)).frame(width: 18, height: 4)
                        Capsule().fill(Color.gray.opacity(0.6)).frame(width: 30, height: 3)
                    }
                } else {
                    // 기본: 시스템 모양을 따름 (밝음/어두움 반반)
                    HStack(spacing: 0) {
                        Rectangle().fill(Color(white: 0.96))
                        Rectangle().fill(Color(white: 0.18))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary)
                }
            }
            .frame(height: 38)
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary, lineWidth: on ? 2 : 0).padding(-2))
            Text(p.name).font(.caption)
        }
        .contentShape(Rectangle())
        .onTapGesture { preset = p.id }
    }
}
