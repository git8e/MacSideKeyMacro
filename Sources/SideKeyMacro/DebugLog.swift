import Foundation

/// 轻量级事件日志，仅在 UserDefaults `sidemacro.debugEvents` 为 true 时写入。
/// 用于排查「侧键按住没反应、松开才触发」这类事件顺序问题。
enum DebugLog {
    static let defaultsKey = "sidemacro.debugEvents"
    static let fileURL = URL(fileURLWithPath: "/tmp/sidekey-events.log")

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func log(_ message: String) {
        guard isEnabled else { return }
        let line = String(format: "%.3f %@\n", Date().timeIntervalSince1970, message)
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: fileURL)
        }
    }
}
