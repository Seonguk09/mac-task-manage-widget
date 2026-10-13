import AppKit
import SwiftUI

/// macOS 버전마다 SwiftUI segmented Picker 폭이 다르다(14/15 는 글자 폭, 26 은 꽉 참).
/// NSSegmentedControl 을 직접 써서 어디서나 같은 폭으로 꽉 채운다.
struct TabSegmentedControl: NSViewRepresentable {
    let items: [(id: String, title: String)]
    @Binding var selection: String
    @Environment(\.atmThemed) private var themed
    @Environment(\.atmAccent) private var accent

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: items.map(\.title), trackingMode: .selectOne,
                                         target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        control.segmentDistribution = .fillEqually
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        if control.segmentCount != items.count {
            control.segmentCount = items.count
        }
        for (i, item) in items.enumerated() where control.label(forSegment: i) != item.title {
            control.setLabel(item.title, forSegment: i)
        }
        control.selectedSegmentBezelColor = themed ? NSColor(accent) : nil
        control.selectedSegment = items.firstIndex { $0.id == selection } ?? 0
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: TabSegmentedControl
        init(_ parent: TabSegmentedControl) { self.parent = parent }

        @objc func changed(_ sender: NSSegmentedControl) {
            let i = sender.selectedSegment
            guard parent.items.indices.contains(i) else { return }
            parent.selection = parent.items[i].id
        }
    }
}

/// 패널 탭 바. 테마 색을 쓰면 직접 그린 "옅은 강조" 탭(포커스를 잃어도 색 유지), 기본 테마면 macOS 기본 세그먼트.
struct PanelTabBar: View {
    let items: [(id: String, title: String)]
    @Binding var selection: String
    @Environment(\.atmThemed) private var themed

    var body: some View {
        if themed {
            SoftAccentTabBar(items: items, selection: $selection)
        } else {
            TabSegmentedControl(items: items, selection: $selection)
        }
    }
}

/// 선택된 탭에 강조색을 옅게 깔고 글자를 강조색으로. NSSegmentedControl 처럼 비활성 창에서 회색이 되지 않는다.
private struct SoftAccentTabBar: View {
    let items: [(id: String, title: String)]
    @Binding var selection: String
    @Environment(\.atmAccent) private var accent
    @Environment(\.colorScheme) private var scheme
    @Environment(\.fontScale) private var scale
    @State private var hovered: String?

    var body: some View {
        let dark = scheme == .dark
        HStack(spacing: 2) {
            ForEach(items, id: \.id) { item in
                let on = item.id == selection
                Button { selection = item.id } label: {
                    Text(item.title)
                        .font(.system(size: 12.5 * scale, weight: on ? .medium : .regular))
                        .foregroundStyle(on ? (dark ? Color.white : accent) : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(on ? accent.opacity(dark ? 0.28 : 0.18)
                                         : (hovered == item.id ? Color.primary.opacity(0.06) : .clear))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? item.id : (hovered == item.id ? nil : hovered) }
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(dark ? 0.06 : 0.05)))
    }
}
