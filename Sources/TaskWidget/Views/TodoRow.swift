import SwiftUI
import TaskWidgetCore

struct TodoRow: View {
    let todo: Todo
    @EnvironmentObject var state: AppState
    @Environment(\.fontScale) private var scale
    @Environment(\.atmAccent) private var accent
    @State private var hovering = false
    @State private var showDue = false
    @State private var showTags = false
    @State private var editing = false
    @State private var draft = ""
    @State private var memoOpen = false
    @State private var memoDraft = ""
    @State private var memoSave: Task<Void, Never>?
    @State private var addingSub = false
    @State private var subDraft = ""
    @FocusState private var subFocused: Bool
    @FocusState private var titleFocused: Bool
    @FocusState private var memoFocused: Bool

    var body: some View {
        let badge = DueBadge.badge(due: todo.dueDate, today: Date())
        let expanded = state.expandedTodos.contains(todo.id)
        VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 8) {
            Button { toggleExpanded() } label: {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9 * scale, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: Self.chevronW * scale, height: 16 * scale)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(expanded ? "접기" : "펼쳐서 메모·하위 할 일 보기")

            Button { state.toggle(todo) } label: {
                Image(systemName: todo.done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13 * scale))
                    .foregroundStyle(todo.done ? accent : Color.secondary)
                    .frame(width: Self.checkW * scale)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
            if editing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5 * scale))
                    .focused($titleFocused)
                    .onSubmit { commitEdit() }
                    .onExitCommand { cancelEdit() }
                    .onChange(of: titleFocused) { _, focused in if !focused && editing { commitEdit() } }
            } else {
                Text(todo.title)
                    .font(.system(size: 12.5 * scale))
                    .strikethrough(todo.done)
                    .foregroundStyle(todo.done ? Color.secondary : Color.primary)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { beginEdit() }
                    .truncationHelp(todo.title, hint: "더블클릭하면 수정")
            }
            if !expanded, let meta = metaLine {
                Text(meta).font(.system(size: 11 * scale)).lineLimit(1)
                    .foregroundStyle(.secondary)
                    .opacity(todo.done ? 0.5 : 1)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleExpanded() }
            }
            }

            Spacer(minLength: 4)

            tagsArea.opacity(todo.done ? 0.5 : 1)

            Button { showDue = true } label: {
                if badge.style == .none {
                    Image(systemName: "calendar")
                        .font(.system(size: 11 * scale))
                        .foregroundStyle(.quaternary)
                } else {
                    Text(badge.text)
                        .font(.system(size: 10.5 * scale, weight: .medium))
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor(badge.style).opacity(0.18))
                        .foregroundStyle(badgeColor(badge.style))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDue) {
                DuePopover(due: todo.dueDate) { key in
                    state.setDue(todo, key)
                }
            }

            Button { state.delete(todo) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9 * scale, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        if expanded { expandedBody }
        }
        .contextMenu {
            Button(expanded ? "접기" : "펼치기") { toggleExpanded() }
            Button("메모 편집") { openMemo() }
            Button("하위 할 일 추가") { openSubAdd() }
            Divider()
            ForEach(state.tagConfig.groups) { group in
                Menu(group.name) {
                    ForEach(group.tags) { tag in
                        Toggle(tag.name, isOn: Binding(
                            get: { todo.tagIds.contains(tag.id) },
                            set: { _ in state.toggleTag(tag.id, on: todo) }
                        ))
                    }
                }
            }
        }
        Divider()
    }

    @ViewBuilder
    private var tagsArea: some View {
        let shown = TagSort.ordered(todo.tagIds, config: state.tagConfig)
        if shown.isEmpty && !hovering && !showTags {
            EmptyView()
        } else {
            Button { showTags = true } label: {
                HStack(spacing: 3) {
                    if shown.isEmpty {
                        Text("＋태그").font(.system(size: 11 * scale)).foregroundStyle(.tertiary)
                    } else {
                        ForEach(shown.prefix(2)) { TagCapsule(tag: $0) }
                        if shown.count > 2 {
                            Text("+\(shown.count - 2)").font(.system(size: 11 * scale)).foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showTags) { TagPopover(todo: todo).environmentObject(state) }
        }
    }

    private static let chevronW: CGFloat = 10
    private static let checkW: CGFloat = 14

    /// 접힌 상태 한 줄: "2/4 · 메모 첫 줄". 둘 다 없으면 nil.
    private var metaLine: String? {
        var parts: [String] = []
        let p = todo.subtaskProgress
        if p.total > 0 { parts.append("\(p.done)/\(p.total)") }
        if let m = todo.memoPreview { parts.append(m) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 11 * scale)).foregroundStyle(.tertiary)
    }

    private var expandedBody: some View {
        let p = todo.subtaskProgress
        return VStack(alignment: .leading, spacing: 3) {
            sectionLabel("메모")
            if memoOpen {
                memoEditor
            } else if todo.memo.isEmpty {
                Button { openMemo() } label: {
                    Text("＋ 메모 추가").font(.system(size: 12 * scale)).foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Text(todo.memo)
                    .font(.system(size: 12.5 * scale))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { openMemo() }
            }
            sectionLabel(p.total > 0 ? "하위 할 일 \(p.done)/\(p.total)" : "하위 할 일").padding(.top, 5)
            ForEach(todo.subtasks) { SubtaskRow(todo: todo, sub: $0) }
            if addingSub {
                TextField("하위 할 일", text: $subDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12 * scale))
                    .focused($subFocused)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(subFocused ? accent : Color.primary.opacity(0.12), lineWidth: subFocused ? 1.5 : 0.5))
                    .onSubmit { submitSub() }
                    .onExitCommand { addingSub = false; subDraft = "" }
            } else {
                Button { openSubAdd() } label: {
                    Text("＋ 하위 할 일 추가").font(.system(size: 12 * scale)).foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(todo.done ? 0.6 : 1)
        .padding(.leading, (Self.chevronW + Self.checkW) * scale + 16)
        .padding(.bottom, 6)
    }

    private func toggleExpanded() {
        if state.expandedTodos.contains(todo.id) {
            if memoOpen { toggleMemo() }
            addingSub = false; subDraft = ""
        }
        state.toggleExpanded(todo)
    }

    private func openMemo() {
        if !state.expandedTodos.contains(todo.id) { state.toggleExpanded(todo) }
        if !memoOpen { toggleMemo() }
    }

    private func openSubAdd() {
        if !state.expandedTodos.contains(todo.id) { state.toggleExpanded(todo) }
        addingSub = true
        DispatchQueue.main.async { subFocused = true }
    }

    /// Enter: 추가하고 다음 입력을 위해 열어 둔다. 빈 입력이면 닫는다.
    private func submitSub() {
        guard Todo.normalizedTitle(subDraft) != nil else { addingSub = false; subDraft = ""; return }
        state.addSubtask(todo, subDraft)
        subDraft = ""
        DispatchQueue.main.async { subFocused = true }
    }

    private var memoEditor: some View {
        TextEditor(text: $memoDraft)
            .font(.system(size: 12 * scale))
            .scrollContentBackground(.hidden)
            .focused($memoFocused)
            .onExitCommand { toggleMemo() }
            .onChange(of: memoFocused) { _, f in if !f && memoOpen { toggleMemo() } }
            .onChange(of: memoDraft) { _, new in
                memoSave?.cancel()
                memoSave = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if !Task.isCancelled { state.setMemo(todo, new) }
                }
            }
            .overlay(alignment: .topLeading) {
                if memoDraft.isEmpty {
                    Text("메모 (여러 줄, - 목록·링크 가능)")
                        .font(.system(size: 12 * scale)).foregroundStyle(.tertiary)
                        .padding(.leading, 5).allowsHitTesting(false)
                }
            }
            .frame(minHeight: 12 * scale * 3 * 1.3, maxHeight: 12 * scale * 8 * 1.3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(4)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .onDisappear { flushMemo() }
    }

    private func toggleMemo() {
        if memoOpen {
            flushMemo()
            memoOpen = false
        } else {
            memoDraft = todo.memo
            memoOpen = true
            DispatchQueue.main.async { memoFocused = true }
        }
    }

    private func flushMemo() {
        memoSave?.cancel()
        memoSave = nil
        if memoOpen { state.setMemo(todo, memoDraft) }
    }

    private func beginEdit() {
        draft = todo.title
        editing = true
        DispatchQueue.main.async { titleFocused = true }
    }

    private func commitEdit() {
        guard editing else { return }
        editing = false
        state.rename(todo, draft)
    }

    private func cancelEdit() {
        editing = false
        draft = todo.title
    }
}

private func badgeColor(_ style: DueStyle) -> Color {
    switch style {
    case .overdue: return .red
    case .today: return .orange
    default: return .secondary
    }
}

struct SubtaskRow: View {
    let todo: Todo
    let sub: Subtask
    @EnvironmentObject var state: AppState
    @Environment(\.fontScale) private var scale
    @Environment(\.atmAccent) private var accent
    @State private var hovering = false
    @State private var showDue = false
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        let badge = DueBadge.badge(due: sub.dueDate, today: Date())
        HStack(spacing: 6) {
            Button { state.toggleSubtask(todo, sub) } label: {
                Image(systemName: sub.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(sub.done ? accent : Color.secondary)
            }
            .buttonStyle(.plain)

            if editing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12 * scale))
                    .focused($focused)
                    .onSubmit { commit() }
                    .onExitCommand { editing = false }
                    .onChange(of: focused) { _, f in if !f && editing { commit() } }
            } else {
                Text(sub.title)
                    .font(.system(size: 12 * scale))
                    .strikethrough(sub.done)
                    .foregroundStyle(sub.done ? Color.secondary : Color.primary)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { draft = sub.title; editing = true; DispatchQueue.main.async { focused = true } }
                    .truncationHelp(sub.title, hint: "더블클릭하면 수정")
            }

            Spacer(minLength: 4)

            Button { showDue = true } label: {
                if badge.style == .none {
                    Image(systemName: "calendar")
                        .font(.system(size: 10 * scale))
                        .foregroundStyle(.quaternary)
                        .opacity(hovering || showDue ? 1 : 0)
                } else {
                    Text(badge.text)
                        .font(.system(size: 10 * scale, weight: .medium))
                        .monospacedDigit()
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(badgeColor(badge.style).opacity(0.18))
                        .foregroundStyle(badgeColor(badge.style))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDue) {
                DuePopover(due: sub.dueDate) { state.setSubtaskDue(todo, sub, $0) }
            }

            Button { state.deleteSubtask(todo, sub) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8 * scale, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private func commit() {
        guard editing else { return }
        editing = false
        state.renameSubtask(todo, sub, draft)
    }
}
