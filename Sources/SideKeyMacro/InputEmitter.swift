import CoreGraphics
import Foundation

/// 负责真正发送键盘/鼠标事件。
enum InputEmitter {
    static func currentMouseLocation() -> CGPoint {
        if let e = CGEvent(source: nil) {
            return e.location
        }
        return .zero
    }

    static func postKey(code: CGKeyCode, down: Bool, flags: UInt64) {
        guard let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { return }
        if flags != 0 {
            e.flags = CGEventFlags(rawValue: flags)
        }
        e.post(tap: .cghidEventTap)
    }

    static func postMouse(down: Bool, button: MacroMouseButton) {
        let loc = currentMouseLocation()
        let src = CGEventSource(stateID: .combinedSessionState)

        let type: CGEventType
        let cgButton: CGMouseButton
        switch button {
        case .left:
            type = down ? .leftMouseDown : .leftMouseUp
            cgButton = .left
        case .right:
            type = down ? .rightMouseDown : .rightMouseUp
            cgButton = .right
        case .middle:
            type = down ? .otherMouseDown : .otherMouseUp
            cgButton = .center
        case .button4, .button5:
            type = down ? .otherMouseDown : .otherMouseUp
            cgButton = .center
        }

        guard let e = CGEvent(
            mouseEventSource: src,
            mouseType: type,
            mouseCursorPosition: loc,
            mouseButton: cgButton
        ) else { return }

        if button == .button4 || button == .button5 {
            e.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button.buttonNumber))
        }
        e.post(tap: .cghidEventTap)
    }
}

/// 记录当前被“按住”的输入，进程退出时兜底释放，避免按键/鼠标键卡住。
final class HeldInputRegistry: @unchecked Sendable {
    static let shared = HeldInputRegistry()

    private let lock = NSLock()
    private var keys: [CGKeyCode: UInt64] = [:]
    private var buttons: Set<MacroMouseButton> = []
    private var exitHookInstalled = false

    private init() {}

    func installExitHook() {
        lock.lock()
        let need = !exitHookInstalled
        exitHookInstalled = true
        lock.unlock()
        guard need else { return }
        atexit {
            HeldInputRegistry.shared.releaseAll()
        }
    }

    func pressKey(_ code: CGKeyCode, flags: UInt64) {
        lock.lock()
        keys[code] = flags
        lock.unlock()
        InputEmitter.postKey(code: code, down: true, flags: flags)
    }

    func releaseKey(_ code: CGKeyCode, flags: UInt64) {
        lock.lock()
        keys.removeValue(forKey: code)
        lock.unlock()
        InputEmitter.postKey(code: code, down: false, flags: flags)
    }

    func pressButton(_ button: MacroMouseButton) {
        lock.lock()
        buttons.insert(button)
        lock.unlock()
        InputEmitter.postMouse(down: true, button: button)
    }

    func releaseButton(_ button: MacroMouseButton) {
        lock.lock()
        buttons.remove(button)
        lock.unlock()
        InputEmitter.postMouse(down: false, button: button)
    }

    func releaseAll() {
        lock.lock()
        let heldButtons = buttons
        let heldKeys = keys
        buttons.removeAll()
        keys.removeAll()
        lock.unlock()

        for button in heldButtons {
            InputEmitter.postMouse(down: false, button: button)
        }
        for (code, flags) in heldKeys {
            InputEmitter.postKey(code: code, down: false, flags: flags)
        }
    }
}
