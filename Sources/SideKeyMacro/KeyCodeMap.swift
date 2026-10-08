import Carbon
import CoreGraphics
import Foundation

enum KeyCodeMap {
    static func key(from code: CGKeyCode) -> MacroKey {
        MacroKey(code: Int(code), display: displayName(for: code))
    }

    static func displayName(for code: CGKeyCode) -> String {
        switch Int(code) {
        case kVK_Shift: return "shift"
        case kVK_RightShift: return "rshift"
        case kVK_Control: return "ctrl"
        case kVK_RightControl: return "rctrl"
        case kVK_Command: return "cmd"
        case kVK_RightCommand: return "rcmd"
        case kVK_Option: return "opt"
        case kVK_RightOption: return "ropt"
        case kVK_Space: return "space"
        case kVK_Return: return "enter"
        case kVK_Tab: return "tab"
        case kVK_Delete: return "backspace"
        case kVK_Escape: return "esc"

        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"

        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"

        default:
            return "vk_\(Int(code))"
        }
    }

    /// 美式布局下，标点字符 → (虚拟键码, 是否需要 Shift)。
    /// 注意 `{` `}` 在宏语法里是标签定界符，无法作为按键输入。
    static func punctuation(from c: Character) -> (code: CGKeyCode, shift: Bool)? {
        switch c {
        case "=": return (CGKeyCode(kVK_ANSI_Equal), false)
        case "+": return (CGKeyCode(kVK_ANSI_Equal), true)
        case "-": return (CGKeyCode(kVK_ANSI_Minus), false)
        case "_": return (CGKeyCode(kVK_ANSI_Minus), true)
        case "[": return (CGKeyCode(kVK_ANSI_LeftBracket), false)
        case "]": return (CGKeyCode(kVK_ANSI_RightBracket), false)
        case ";": return (CGKeyCode(kVK_ANSI_Semicolon), false)
        case ":": return (CGKeyCode(kVK_ANSI_Semicolon), true)
        case "'": return (CGKeyCode(kVK_ANSI_Quote), false)
        case "\"": return (CGKeyCode(kVK_ANSI_Quote), true)
        case ",": return (CGKeyCode(kVK_ANSI_Comma), false)
        case "<": return (CGKeyCode(kVK_ANSI_Comma), true)
        case ".": return (CGKeyCode(kVK_ANSI_Period), false)
        case ">": return (CGKeyCode(kVK_ANSI_Period), true)
        case "/": return (CGKeyCode(kVK_ANSI_Slash), false)
        case "?": return (CGKeyCode(kVK_ANSI_Slash), true)
        case "\\": return (CGKeyCode(kVK_ANSI_Backslash), false)
        case "|": return (CGKeyCode(kVK_ANSI_Backslash), true)
        case "`": return (CGKeyCode(kVK_ANSI_Grave), false)
        case "~": return (CGKeyCode(kVK_ANSI_Grave), true)
        case "!": return (CGKeyCode(kVK_ANSI_1), true)
        case "@": return (CGKeyCode(kVK_ANSI_2), true)
        case "#": return (CGKeyCode(kVK_ANSI_3), true)
        case "$": return (CGKeyCode(kVK_ANSI_4), true)
        case "%": return (CGKeyCode(kVK_ANSI_5), true)
        case "^": return (CGKeyCode(kVK_ANSI_6), true)
        case "&": return (CGKeyCode(kVK_ANSI_7), true)
        case "*": return (CGKeyCode(kVK_ANSI_8), true)
        case "(": return (CGKeyCode(kVK_ANSI_9), true)
        case ")": return (CGKeyCode(kVK_ANSI_0), true)
        default: return nil
        }
    }

    static func keyCode(from displayOrVK: String) -> CGKeyCode? {
        let s = displayOrVK.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("vk_") {
            let n = s.dropFirst(3)
            if let i = Int(n) {
                return CGKeyCode(i)
            }
        }

        switch s {
        case "shift": return CGKeyCode(kVK_Shift)
        case "rshift": return CGKeyCode(kVK_RightShift)
        case "ctrl": return CGKeyCode(kVK_Control)
        case "rctrl": return CGKeyCode(kVK_RightControl)
        case "cmd": return CGKeyCode(kVK_Command)
        case "rcmd": return CGKeyCode(kVK_RightCommand)
        case "opt": return CGKeyCode(kVK_Option)
        case "ropt": return CGKeyCode(kVK_RightOption)
        case "space": return CGKeyCode(kVK_Space)
        case "enter": return CGKeyCode(kVK_Return)
        case "tab": return CGKeyCode(kVK_Tab)
        case "backspace": return CGKeyCode(kVK_Delete)
        case "esc": return CGKeyCode(kVK_Escape)

        case "a": return CGKeyCode(kVK_ANSI_A)
        case "b": return CGKeyCode(kVK_ANSI_B)
        case "c": return CGKeyCode(kVK_ANSI_C)
        case "d": return CGKeyCode(kVK_ANSI_D)
        case "e": return CGKeyCode(kVK_ANSI_E)
        case "f": return CGKeyCode(kVK_ANSI_F)
        case "g": return CGKeyCode(kVK_ANSI_G)
        case "h": return CGKeyCode(kVK_ANSI_H)
        case "i": return CGKeyCode(kVK_ANSI_I)
        case "j": return CGKeyCode(kVK_ANSI_J)
        case "k": return CGKeyCode(kVK_ANSI_K)
        case "l": return CGKeyCode(kVK_ANSI_L)
        case "m": return CGKeyCode(kVK_ANSI_M)
        case "n": return CGKeyCode(kVK_ANSI_N)
        case "o": return CGKeyCode(kVK_ANSI_O)
        case "p": return CGKeyCode(kVK_ANSI_P)
        case "q": return CGKeyCode(kVK_ANSI_Q)
        case "r": return CGKeyCode(kVK_ANSI_R)
        case "s": return CGKeyCode(kVK_ANSI_S)
        case "t": return CGKeyCode(kVK_ANSI_T)
        case "u": return CGKeyCode(kVK_ANSI_U)
        case "v": return CGKeyCode(kVK_ANSI_V)
        case "w": return CGKeyCode(kVK_ANSI_W)
        case "x": return CGKeyCode(kVK_ANSI_X)
        case "y": return CGKeyCode(kVK_ANSI_Y)
        case "z": return CGKeyCode(kVK_ANSI_Z)

        case "0": return CGKeyCode(kVK_ANSI_0)
        case "1": return CGKeyCode(kVK_ANSI_1)
        case "2": return CGKeyCode(kVK_ANSI_2)
        case "3": return CGKeyCode(kVK_ANSI_3)
        case "4": return CGKeyCode(kVK_ANSI_4)
        case "5": return CGKeyCode(kVK_ANSI_5)
        case "6": return CGKeyCode(kVK_ANSI_6)
        case "7": return CGKeyCode(kVK_ANSI_7)
        case "8": return CGKeyCode(kVK_ANSI_8)
        case "9": return CGKeyCode(kVK_ANSI_9)

        default:
            return nil
        }
    }
}
