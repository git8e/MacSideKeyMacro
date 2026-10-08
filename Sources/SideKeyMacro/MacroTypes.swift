import Foundation

enum MacroMouseButton: String, Codable, Sendable, CaseIterable, Identifiable {
    case left
    case right
    case middle
    case button4
    case button5

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return L10n.mouseLeft
        case .right: return L10n.mouseRight
        case .middle: return L10n.mouseMiddle
        case .button4: return L10n.mouseButton4
        case .button5: return L10n.mouseButton5
        }
    }

    /// CGEvent `mouseEventButtonNumber`: 0 left, 1 right, 2 middle, 3 X1(侧键4), 4 X2(侧键5).
    var buttonNumber: Int {
        switch self {
        case .left: return 0
        case .right: return 1
        case .middle: return 2
        case .button4: return 3
        case .button5: return 4
        }
    }

    static func fromButtonNumber(_ n: Int) -> MacroMouseButton? {
        switch n {
        case 0: return .left
        case 1: return .right
        case 2: return .middle
        case 3: return .button4
        case 4: return .button5
        default: return nil
        }
    }
}

struct MacroKey: Codable, Equatable, Sendable {
    var code: Int
    var display: String
    /// `CGEventFlags.rawValue`（修饰键状态，例如 shift/ctrl/alt/cmd）。
    var flags: UInt64 = 0
}

enum MacroAction: Codable, Equatable, Sendable {
    case wait
    case keyDown(MacroKey)
    case keyUp(MacroKey)
    case mouseDown(button: MacroMouseButton)
    case mouseUp(button: MacroMouseButton)
}

struct MacroItem: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    /// 执行本动作之前的等待时长（秒）。
    var delaySeconds: Double
    var action: MacroAction
}
