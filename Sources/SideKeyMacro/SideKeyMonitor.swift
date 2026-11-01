import CoreGraphics
import Foundation

/// 触发用的鼠标侧键选择。
enum SideButton: String, CaseIterable, Identifiable {
    case button4
    case button5
    case both
    case anyExtra
    case custom

    var id: String { rawValue }

    func title(customButtonNumber: Int?) -> String {
        L10n.sideButtonTitle(self, customButtonNumber: customButtonNumber)
    }

    /// CGEvent 的 `mouseEventButtonNumber`：3 = X1(侧键1)，4 = X2(侧键2)。
    /// 不同鼠标可能把侧键映射到更大的编号（5、6…），因此额外提供「任意额外键」和自定义绑定。
    func matches(buttonNumber: Int, customButtonNumber: Int?) -> Bool {
        switch self {
        case .button4: return buttonNumber == 3
        case .button5: return buttonNumber == 4
        case .both: return buttonNumber == 3 || buttonNumber == 4
        case .anyExtra: return buttonNumber >= 3
        case .custom: return customButtonNumber == buttonNumber
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

    /// 主线程（事件 Tap 所在的 RunLoop）回调，必须同步执行，避免按下/松开被异步任务重排。
    var onButtonDown: (@MainActor () -> Void)?
    var onButtonUp: (@MainActor () -> Void)?
    /// 任意额外鼠标键（编号 >= 3）按下时回调，用于「学习侧键」和界面上的按键检测。
    var onObservedButton: (@MainActor (Int) -> Void)?

    private(set) var isRunning = false

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var button = SideButton.both
    private var customButtonNumber: Int?
    private var intercept = true
    /// 学习模式下只观察按键，不触发宏，也不拦截事件。
    private var isCapturing = false

    func start(button: SideButton, customButtonNumber: Int?, intercept: Bool) throws {
        stop()
        self.button = button
        self.customButtonNumber = customButtonNumber
        self.intercept = intercept
        isCapturing = false

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
        DebugLog.log("TAP START button=\(button.rawValue) custom=\(customButtonNumber.map(String.init) ?? "-") intercept=\(intercept)")
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
        isCapturing = false
    }

    /// 进入/退出学习模式。学习期间不触发宏，也不拦截侧键事件。
    func setCapturing(_ capturing: Bool) {
        isCapturing = capturing
    }

    @MainActor
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // 系统因超时禁用了 Tap，需要立刻重新启用，否则侧键会“失灵”。
            DebugLog.log("TAP DISABLED type=\(type.rawValue)")
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)

        case .otherMouseDown, .otherMouseUp:
            let number = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            DebugLog.log("EVENT \(type == .otherMouseDown ? "DOWN" : "UP") button=\(number)")
            // 只上报额外的鼠标键（侧键等），中键/左右键不参与学习和提示。
            if type == .otherMouseDown, number >= 3 {
                onObservedButton?(number)
            }
            // 学习模式下只上报按键编号，绝不触发或拦截。
            guard !isCapturing,
                  button.matches(buttonNumber: number, customButtonNumber: customButtonNumber) else {
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
    // Tap 安装在主 RunLoop 上，这里同步回到 MainActor，保证 DOWN/UP 的处理顺序。
    return MainActor.assumeIsolated {
        monitor.handle(type: type, event: event)
    }
}
