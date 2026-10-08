import AppKit
import SwiftUI

/// 基于 NSTextView 的脚本编辑器。
/// 相比 SwiftUI 的 TextEditor：焦点稳定（不随父视图刷新丢失）、支持撤销、可关闭 macOS 的智能引号/破折号替换。
struct ScriptTextView: NSViewRepresentable {
    @Binding var text: String

    var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.font = font
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        // 脚本里有 `{WAITMS:100-200}` 这类内容，必须关掉 macOS 的智能替换，否则会把 - 变成 –。
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.textView = textView

        // 切换/新建脚本后自动把光标放进编辑器，避免“点了没反应、字打不进去”。
        DispatchQueue.main.async {
            if let window = scrollView.window, window.isKeyWindow {
                window.makeFirstResponder(textView)
            }
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        guard textView.string != text else { return }
        let previous = textView.selectedRange()
        textView.string = text
        let length = (text as NSString).length
        let location = min(previous.location, length)
        textView.setSelectedRange(NSRange(location: location, length: 0))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ScriptTextView
        weak var textView: NSTextView?

        init(_ parent: ScriptTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }
    }
}
