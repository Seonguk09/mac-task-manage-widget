import SwiftUI
import TaskWidgetCore

/// 전역 단축키 녹화 버튼 + 기본값 복원. 녹화 중에는 전역 등록을 잠시 내려 현재 조합도 다시 누를 수 있다.
struct HotKeyRecorder: View {
    @State private var spec = Settings.shared.globalHotKey
    @State private var recording = false
    @State private var message = ""
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(recording ? "키를 누르세요… (Esc 취소)" : spec.displayString) {
                    recording ? stop() : start()
                }
                if spec != .default && !recording {
                    Button("기본값") { apply(.default) }
                }
            }
            if !message.isEmpty {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        message = ""
        recording = true
        NotificationCenter.default.post(name: .hotKeyRecording, object: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            handle(e)
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard recording else { return }
        recording = false
        NotificationCenter.default.post(name: .hotKeyRecording, object: false)
    }

    private func handle(_ e: NSEvent) {
        let new = HotKeySpec(keyCode: UInt32(e.keyCode),
                             modifiers: HotKeySpec.carbonModifiers(e.modifierFlags))
        if new.keyCode == HotKeySpec.escKeyCode { stop(); return }
        guard new.isValid else { message = "⌘·⌃·⌥ 중 하나를 함께 눌러주세요"; return }
        // 녹화 중에는 전역 등록이 내려가 있으므로 시험 등록이 정확하다.
        guard GlobalHotKey.canRegister(new) else {
            message = "이 조합은 사용할 수 없어요 (다른 앱이 사용 중일 수 있음)"
            stop()
            return
        }
        apply(new)
        stop()
    }

    private func apply(_ new: HotKeySpec) {
        message = ""
        spec = new
        Settings.shared.globalHotKey = new
    }
}
