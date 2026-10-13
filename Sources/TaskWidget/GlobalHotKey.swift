import Carbon.HIToolbox
import TaskWidgetCore

extension Notification.Name {
    /// object: Bool — true 면 단축키 녹화 중이라 전역 등록을 잠시 내린다.
    static let hotKeyRecording = Notification.Name("ATMHotKeyRecording")
}

/// Carbon 전역 단축키. 접근성 권한이 필요 없다.
final class GlobalHotKey {
    private static let id = EventHotKeyID(signature: OSType(0x41544D48), id: 1)  // 'ATMH'
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var current: HotKeySpec?
    private let action: () -> Void

    init(action: @escaping () -> Void) { self.action = action }

    var isRegistered: Bool { ref != nil }

    /// spec 으로 등록(이미 같으면 무시). 실패하면 이전 등록을 그대로 두고 false.
    @discardableResult
    func register(_ spec: HotKeySpec) -> Bool {
        if ref != nil, current == spec { return true }
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
                let me = Unmanaged<GlobalHotKey>.fromOpaque(ctx!).takeUnretainedValue()
                DispatchQueue.main.async { me.action() }
                return noErr
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        var new: EventHotKeyRef?
        guard RegisterEventHotKey(spec.keyCode, spec.modifiers, Self.id, GetApplicationEventTarget(), 0, &new) == noErr
        else { return false }
        if let ref { UnregisterEventHotKey(ref) }
        ref = new; current = spec
        return true
    }

    /// 등록 가능한지 시험(바로 해제). 현재 등록된 조합은 이미 점유 중이라 false 가 나오므로 해제 후 호출할 것.
    static func canRegister(_ spec: HotKeySpec) -> Bool {
        var r: EventHotKeyRef?
        guard RegisterEventHotKey(spec.keyCode, spec.modifiers, id, GetApplicationEventTarget(), 0, &r) == noErr else { return false }
        if let r { UnregisterEventHotKey(r) }
        return true
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        ref = nil; handler = nil; current = nil
    }

    deinit { unregister() }
}
