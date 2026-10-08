import CoreGraphics
import Foundation

/// XMBC（X-Mouse Button Control）"Simulated Keystrokes" 风格宏脚本解析器。
///
/// 支持的标签（大小写不敏感）：
/// - `{WAITMS:n}`  等待 n 毫秒；`{WAIT:n}` 等待 n 秒
/// - `{HOLDMS:n}`  让**下一个**按键/点击按住 n 毫秒；`{HOLD:n}` 单位为秒
/// - `{LMB}` `{RMB}` `{MMB}` `{MB4}` `{MB5}`  一次完整点击（按下 → 按住 → 抬起）
/// - `{LMBD}` `{LMBU}`（RMB/MMB/MB4/MB5 同理）  单独按下 / 单独抬起
/// - `{SHIFT}` `{CTRL}` `{ALT}` `{CMD}` 修饰键，持续生效直到 `{CLEAR}`
/// - 其余普通字符（如 `s`）视为一次按键
/// - `{WAITMS:100-200}` 随机等待 100~200 毫秒
enum MacroDSL {
    /// 未指定 `{HOLDMS}` 时，普通按键/点击的默认按住时长。
    static let defaultHoldMs: Double = 30

    enum ParseError: Error, LocalizedError {
        case empty
        case unclosedTag
        case invalidTag(String)
        case missingArgument(String)
        case invalidArgument(String)
        case unsupportedKey(String)

        var errorDescription: String? {
            switch self {
            case .empty:
                return L10n.errEmpty
            case .unclosedTag:
                return L10n.errUnclosedTag
            case .invalidTag(let t):
                return L10n.errInvalidTag(t)
            case .missingArgument(let t):
                return L10n.errMissingArgument(t)
            case .invalidArgument(let t):
                return L10n.errInvalidArgument(t)
            case .unsupportedKey(let k):
                return L10n.errUnsupportedKey(k)
            }
        }
    }

    static func parse(_ text: String, defaultHoldMs: Double = MacroDSL.defaultHoldMs) throws -> [MacroItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.empty }

        var items: [MacroItem] = []
        var pendingHoldMs: Double? = nil
        var pendingFlags: UInt64 = 0

        enum TagKind { case click, down, up }

        func takeHoldMs() -> Double {
            let hold = pendingHoldMs ?? defaultHoldMs
            pendingHoldMs = nil
            return hold
        }

        func append(_ action: MacroAction, delaySeconds: Double = 0) {
            items.append(MacroItem(delaySeconds: max(0, delaySeconds), action: action))
        }

        func appendWait(seconds: Double) {
            guard seconds > 0 else { return }
            append(.wait, delaySeconds: seconds)
        }

        func appendClick(_ button: MacroMouseButton) {
            append(.mouseDown(button: button))
            append(.mouseUp(button: button), delaySeconds: takeHoldMs() / 1000.0)
        }

        func appendButton(_ button: MacroMouseButton, kind: TagKind) {
            switch kind {
            case .click:
                appendClick(button)
            case .down:
                append(.mouseDown(button: button))
                // `{HOLDMS}` 只作用于“按下+抬起”成对的动作，这里直接消费掉，避免泄漏到后续按键。
                pendingHoldMs = nil
            case .up:
                append(.mouseUp(button: button))
                pendingHoldMs = nil
            }
        }

        func appendKeyPress(code: CGKeyCode, display: String, flags: UInt64) {
            let key = MacroKey(code: Int(code), display: display, flags: flags)
            append(.keyDown(key))
            append(.keyUp(key), delaySeconds: takeHoldMs() / 1000.0)
        }

        func parseNumber(_ raw: String, tag: String) throws -> Double {
            let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { throw ParseError.missingArgument(tag) }
            if let v = Double(s) { return v }
            // 随机区间 a-b
            let parts = s.split(separator: "-", maxSplits: 1)
            if parts.count == 2, let lo = Double(parts[0]), let hi = Double(parts[1]), hi >= lo {
                return lo + Double.random(in: 0...(hi - lo))
            }
            throw ParseError.invalidArgument(tag)
        }

        func buttonTag(_ name: String) -> (button: MacroMouseButton, kind: TagKind)? {
            let base: String
            let kind: TagKind
            if name.hasSuffix("D") && name.count > 1 {
                base = String(name.dropLast())
                kind = .down
            } else if name.hasSuffix("U") && name.count > 1 {
                base = String(name.dropLast())
                kind = .up
            } else {
                base = name
                kind = .click
            }
            switch base {
            case "LMB": return (.left, kind)
            case "RMB": return (.right, kind)
            case "MMB": return (.middle, kind)
            case "MB4": return (.button4, kind)
            case "MB5": return (.button5, kind)
            default: return nil
            }
        }

        func handleTag(_ rawTag: String) throws {
            let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty else { throw ParseError.invalidTag(rawTag) }

            let colon = tag.firstIndex(of: ":")
            let name = String(colon.map { tag[tag.startIndex..<$0] } ?? tag[...]).uppercased()
            let arg = colon.map { String(tag[tag.index(after: $0)...]) }

            switch name {
            case "WAITMS":
                appendWait(seconds: max(0, try parseNumber(arg ?? "", tag: tag)) / 1000.0)
            case "WAIT":
                appendWait(seconds: max(0, try parseNumber(arg ?? "", tag: tag)))
            case "HOLDMS":
                pendingHoldMs = max(0, try parseNumber(arg ?? "", tag: tag))
            case "HOLD":
                pendingHoldMs = max(0, try parseNumber(arg ?? "", tag: tag)) * 1000.0
            case "CLEAR":
                pendingFlags = 0
            case "SHIFT":
                pendingFlags |= CGEventFlags.maskShift.rawValue
            case "CTRL", "CONTROL":
                pendingFlags |= CGEventFlags.maskControl.rawValue
            case "ALT", "OPTION":
                pendingFlags |= CGEventFlags.maskAlternate.rawValue
            case "CMD", "COMMAND", "WIN":
                pendingFlags |= CGEventFlags.maskCommand.rawValue
            case "VKC", "EXT":
                // XMBC 兼容：直接发送原始虚拟键码。
                let raw = Int(try parseNumber(arg ?? "", tag: tag))
                appendKeyPress(code: CGKeyCode(raw), display: "vk_\(raw)", flags: pendingFlags)
            default:
                if let t = buttonTag(name) {
                    appendButton(t.button, kind: t.kind)
                    return
                }
                throw ParseError.invalidTag(rawTag)
            }
        }

        func handleChar(_ c: Character) throws {
            if c == "\n" || c == "\r" || c == "\t" { return }

            let display: String
            let code: CGKeyCode
            var needShift = false

            if c == " " || c.isLetter || c.isNumber {
                display = (c == " ") ? "space" : String(c).lowercased()
                guard let mapped = KeyCodeMap.keyCode(from: display) else {
                    throw ParseError.unsupportedKey(String(c))
                }
                code = mapped
                needShift = c.isUppercase && c.isLetter
            } else if let mapped = KeyCodeMap.punctuation(from: c) {
                display = String(c)
                code = mapped.code
                needShift = mapped.shift
            } else {
                throw ParseError.unsupportedKey(String(c))
            }

            var flags = pendingFlags
            if needShift {
                flags |= CGEventFlags.maskShift.rawValue
            }
            appendKeyPress(code: code, display: display, flags: flags)
        }

        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "{" {
                guard let close = chars[(i + 1)...].firstIndex(of: "}") else { throw ParseError.unclosedTag }
                let tag = String(chars[(i + 1)..<close])
                i = close + 1
                try handleTag(tag)
            } else if c == "}" {
                throw ParseError.invalidTag("}")
            } else {
                try handleChar(c)
                i += 1
            }
        }

        return items
    }

    static func durationSeconds(of items: [MacroItem]) -> Double {
        items.reduce(0) { $0 + $1.delaySeconds }
    }

    static func durationText(of items: [MacroItem]) -> String {
        let total = durationSeconds(of: items)
        if total < 60 {
            return L10n.durationUnderMinute(total)
        }
        return L10n.durationOverMinute(total / 60, total.truncatingRemainder(dividingBy: 60))
    }
}
