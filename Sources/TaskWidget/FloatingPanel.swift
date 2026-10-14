import AppKit
import TaskWidgetCore

final class FloatingPanel: NSPanel, NSWindowDelegate {
    private var hovering = false

    convenience init(content: NSView) {
        self.init(contentRect: NSRect(x: 0, y: 0, width: 320, height: 520),
                  styleMask: [.nonactivatingPanel, .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                  backing: .buffered, defer: false)
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 280, height: 360)
        standardWindowButton(.zoomButton)?.isHidden = true
        contentView = content
        delegate = self

        setFrameAutosaveName("TaskWidgetPanel")
        if !setFrameUsingName("TaskWidgetPanel") { center() }
        // 예전에 접힌 채 저장된 프레임이 복원돼도 패널이 작아지지 않게 한다 (위쪽 가장자리 유지).
        if frame.height < 360 { var f = frame; f.origin.y -= 520 - f.height; f.size.height = 520; setFrame(f, display: false) }

        let tracking = NSTrackingArea(rect: .zero,
                                      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                      owner: self, userInfo: nil)
        content.addTrackingArea(tracking)
        applyAppearance()
    }

    /// nonactivating 패널에서도 텍스트 입력을 받으려면 key 가 될 수 있어야 한다.
    override var canBecomeKey: Bool { true }

    /// 창이 key 가 될 때 macOS 가 첫 입력칸에 커서를 자동으로 넣는다. 열자마자 입력칸이 선택돼 있지 않게 비운다.
    /// (⌘N 새 할 일은 그 다음에 포커스를 따로 요청하므로 영향 없음)
    override func becomeKey() {
        super.becomeKey()
        clearAutoFocus()
        // SwiftUI 가 다음 런루프에 다시 넣는 경우가 있어 한 번 더. ⌘N 요청 중이면 건드리지 않는다.
        DispatchQueue.main.async { [weak self] in self?.clearAutoFocus() }
    }

    /// ⌘N "새 할 일" 처럼 입력칸 포커스를 일부러 요청할 때 true 로 두면 자동 해제를 건너뛴다.
    var keepFocusOnce = false

    private func clearAutoFocus() {
        if keepFocusOnce { keepFocusOnce = false; return }
        if firstResponder is NSTextView || firstResponder is NSTextField { makeFirstResponder(nil) }
    }

    /// 입력칸이 아닌 곳(할 일 줄, 빈 공간 등)을 누르면 입력칸 선택을 푼다. AppKit 은 기본적으로 커서를 그대로 둔다.
    override func sendEvent(_ event: NSEvent) {
        let clickedText = event.type == .leftMouseDown && Self.isTextInput(hit(event))
        super.sendEvent(event)
        if event.type == .leftMouseDown, !clickedText, firstResponder is NSTextView {
            makeFirstResponder(nil)
        }
    }

    private func hit(_ event: NSEvent) -> NSView? {
        guard let content = contentView, let frame = content.superview else { return nil }
        return frame.hitTest(frame.convert(event.locationInWindow, from: nil))
    }

    private static func isTextInput(_ view: NSView?) -> Bool {
        var v = view
        while let cur = v {
            if cur is NSTextView || (cur is NSTextField && (cur as! NSTextField).isEditable) { return true }
            v = cur.superview
        }
        return false
    }

    func applyAppearance() {
        let s = Settings.shared
        level = s.alwaysOnTop ? .floating : .normal
        collectionBehavior = s.allSpaces ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.moveToActiveSpace]
        alphaValue = (hovering && s.hoverOpaque) ? 1.0 : s.opacity
        if let c = s.themeColors, let bg = HexColor.rgb(c.background) {
            // 테마 색: 배경에 맞춰 라이트/다크 외형을 강제해 글자색이 읽히게 한다.
            backgroundColor = NSColor(srgbRed: bg.r, green: bg.g, blue: bg.b, alpha: 1)
            appearance = NSAppearance(named: c.isDark ? .darkAqua : .aqua)
            return
        }
        backgroundColor = .windowBackgroundColor
        switch s.theme {
        case "light": appearance = NSAppearance(named: .aqua)
        case "dark": appearance = NSAppearance(named: .darkAqua)
        default: appearance = nil
        }
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        applyAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        applyAppearance()
    }

    func toggle() {
        if isMiniaturized {
            deminiaturize(nil)
            makeKeyAndOrderFront(nil)
        } else if isVisible {
            orderOut(nil)
        } else {
            makeKeyAndOrderFront(nil)
        }
    }

    /// 어떤 경로로 숨겨지든 hover 상태와 alpha 를 함께 되돌려, 다시 보일 때 불투명으로 나오지 않게 한다.
    override func orderOut(_ sender: Any?) {
        hovering = false
        applyAppearance()
        super.orderOut(sender)
        // 잠긴 메모를 다시 잠글 수 있게 알린다.
        NotificationCenter.default.post(name: .panelDidHide, object: nil)
    }

    /// 닫기 버튼 = 숨기기. 앱은 메뉴바에 계속 산다.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        orderOut(nil)
        return false
    }
}
