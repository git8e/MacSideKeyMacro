import CoreGraphics
import Foundation

/// 触发用的鼠标侧键选择。
enum SideButton: String, CaseIterable, Identifiable {
    case button4
    case button5
    case both

    var id: String { rawValue }

    var title: String {
        L10n.sideButtonTitle(self)
    }

    /// CGEvent 的 `mouseEventButtonNumber`：3 = X1(侧键1)，4 = X2(侧键2)。
    func matches(buttonNumber: Int) -> Bool {
        switch self {
        case .button4: return buttonNumber == 3
        case .button5: return buttonNumber == 4
        case .both: return buttonNumber == 3 || buttonNumber == 4
        }
    }
}

/// 通过 CGEventTap 全局监听鼠标侧键。
final class SideKeyMonitor {
    enum MonitorError: LocalizedError {
        case tapCreateFailed

        var errorDescription: String? {
            switch self {
            case .tapCreateFailed:
                return L10n.tapCreateFailed
            }
        }
    }

    /// 主线程（事件 Tap 所在的 RunLoop）回调。
    var onButtonDown: (() -> Void)?
    var onButtonUp: (() -> Void)?

    private(set) var isRunning = false

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var button = SideButton.both
    private var intercept = true

    func start(button: SideButton, intercept: Bool) throws {
        stop()
        self.button = button
        self.intercept = intercept

        let eventsOfInterest: CGEventMask =
            (CGEventMask(1) << CGEventType.otherMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.otherMouseUp.rawValue) |
            (CGEventMask(1) << CGEventType.tapDisabledByTimeout.rawValue) |
            (CGEventMask(1) << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: sideKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw MonitorError.tapCreateFailed
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isRunning = false
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // 系统因超时禁用了 Tap，需要立刻重新启用，否则侧键会“失灵”。
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)

        case .otherMouseDown, .otherMouseUp:
            let number = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            guard button.matches(buttonNumber: number) else {
                return Unmanaged.passUnretained(event)
            }
            if type == .otherMouseDown {
                onButtonDown?()
            } else {
                onButtonUp?()
            }
            return intercept ? nil : Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    deinit {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }
}

private let sideKeyTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<SideKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
