import Foundation

/// 界面语言选项。
enum AppLanguage: String, CaseIterable, Identifiable {
    /// 跟随系统
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    var id: String { rawValue }
}

/// 界面文案。三元组顺序固定为：English / 简体中文 / 繁體中文。
///
/// 默认「跟随系统」，在设置里可强制指定。切换语言会写入 UserDefaults，
/// AppModel 的 `@Published language` 触发整棵视图重建，因此 body 里的
/// 每个 `L10n.xxx` 都会重新取值。
enum L10n {
    static let prefKey = "sidemacro.language.v1"

    /// 当前选择（可能是 `.system`）。
    static var language: AppLanguage {
        get {
            UserDefaults.standard.string(forKey: prefKey)
                .flatMap(AppLanguage.init(rawValue:)) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: prefKey)
        }
    }

    /// 实际生效的语言。
    static var resolved: AppLanguage {
        switch language {
        case .system: return detectSystemLanguage()
        case .en, .zhHans, .zhHant: return language
        }
    }

    private static func detectSystemLanguage() -> AppLanguage {
        let first = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if first.hasPrefix("zh") {
            let traditionalPrefixes = ["zh-hant", "zh-tw", "zh-hk", "zh-mo"]
            if traditionalPrefixes.contains(where: { first.hasPrefix($0) }) {
                return .zhHant
            }
            return .zhHans
        }
        return .en
    }

    private static func s(_ en: String, _ hans: String, _ hant: String) -> String {
        switch resolved {
        case .en: return en
        case .zhHans, .system: return hans
        case .zhHant: return hant
        }
    }

    // MARK: - 语言选项

    static func languageOption(_ lang: AppLanguage) -> String {
        switch lang {
        case .system: return s("Follow System", "跟随系统", "跟隨系統")
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }

    // MARK: - 窗口与整体

    static var appTitle: String {
        s("Mouse Side-Button Macro", "鼠标侧键宏", "滑鼠側鍵巨集")
    }

    static var footerUsage: String {
        s(
            "How to use: grant Accessibility → turn on “Listen for side buttons” → hold a mouse side button to trigger, release to stop. Default mode loops while held and releases everything on release.",
            "用法：授予「辅助功能」权限 → 打开「启用侧键监听」→ 游戏内按住鼠标侧键触发，松开停止。默认按住循环，松开立即释放所有按键。",
            "用法：授予「輔助功能」權限 → 開啟「啟用側鍵監聽」→ 遊戲內按住滑鼠側鍵觸發，鬆開停止。預設按住循環，鬆開立即釋放所有按鍵。"
        )
    }

    // MARK: - 设置卡片

    static var cardSettings: String { s("Settings", "设置", "設定") }

    static var languageLabel: String { s("Language", "语言", "語言") }

    // MARK: - 权限卡片

    static var cardPermission: String { s("Permissions", "权限", "權限") }

    static var a11yGranted: String {
        s("Accessibility granted", "辅助功能已授权", "輔助功能已授權")
    }

    static var a11yDenied: String {
        s("Accessibility not granted", "辅助功能未授权", "輔助功能未授權")
    }

    static var goToSettings: String { s("Open Settings", "前往授权", "前往授權") }

    static var refreshStatus: String { s("Refresh", "刷新状态", "重新整理狀態") }

    // MARK: - 触发卡片

    static var cardTrigger: String { s("Trigger", "触发", "觸發") }

    static var enableMonitor: String {
        s("Listen for side buttons", "启用侧键监听", "啟用側鍵監聽")
    }

    static var triggerSideKey: String { s("Trigger button", "触发侧键", "觸發側鍵") }

    static var interceptToggle: String {
        s(
            "Intercept side-button events (game/system won't receive them)",
            "拦截侧键事件（游戏/系统收不到）",
            "攔截側鍵事件（遊戲/系統收不到）"
        )
    }

    static var triggerModeLabel: String { s("Trigger mode", "触发方式", "觸發方式") }

    static var modeOnce: String { s("Press once, run once", "按一次执行一次", "按一次執行一次") }

    static var modeHoldLoop: String {
        s("Hold to loop · release to stop", "按住循环 · 松开停止", "按住循環 · 鬆開停止")
    }

    static var modeHoldLoopDetail: String {
        s(
            "Loops continuously while the side button is held; releasing aborts immediately and releases every key and mouse button.",
            "按住侧键连续循环执行，松开立即中止并释放所有按键/鼠标键。",
            "按住側鍵連續循環執行，鬆開立即中止並釋放所有按鍵/滑鼠鍵。"
        )
    }

    static var modeHoldFinish: String {
        s(
            "Hold to loop · release to finish the pass",
            "按住循环 · 松开跑完这一遍",
            "按住循環 · 鬆開跑完這一遍"
        )
    }

    static var modeHoldFinishDetail: String {
        s(
            "Loops continuously while held; releasing finishes the current pass before stopping.",
            "按住侧键连续循环，松开后把当前这一遍跑完再停。",
            "按住側鍵連續循環，鬆開後把當前這一遍跑完再停。"
        )
    }

    static var modeOnceDetail: String {
        s(
            "Each press runs the macro once from start to finish; pressing again during a run is ignored.",
            "每次按下侧键完整跑一遍，执行期间再次按下无效。",
            "每次按下側鍵完整跑一遍，執行期間再次按下無效。"
        )
    }

    static func modeTitle(_ mode: MacroRunner.TriggerMode) -> String {
        switch mode {
        case .once: return modeOnce
        case .holdLoop: return modeHoldLoop
        case .holdFinish: return modeHoldFinish
        }
    }

    static func modeDetail(_ mode: MacroRunner.TriggerMode) -> String {
        switch mode {
        case .once: return modeOnceDetail
        case .holdLoop: return modeHoldLoopDetail
        case .holdFinish: return modeHoldFinishDetail
        }
    }

    // MARK: - 手动控制

    static var cardManual: String { s("Manual Control", "手动控制", "手動控制") }

    static var stopButton: String { s("Stop", "停止", "停止") }

    static var runOnceButton: String { s("Run Once", "运行一次", "執行一次") }

    // MARK: - 运行状态

    static var statusIdle: String { s("Idle", "待机", "待機") }

    static var statusStopped: String { s("Stopped", "已停止", "已停止") }

    static var statusRunningLoop: String { s("Looping…", "循环执行中…", "循環執行中…") }

    static var statusRunningOnce: String { s("Running…", "执行中…", "執行中…") }

    static var statusEmptyMacro: String { s("Macro is empty", "宏为空", "巨集為空") }

    // MARK: - 脚本库

    static var cardMacro: String { s("Macro Scripts", "宏脚本库", "巨集腳本庫") }

    static var scriptPlaceholder: String {
        s(
            "Paste or type a macro script here (XMBC syntax), e.g. {LMBD}{WAITMS:120}{RMB}…",
            "在此粘贴或输入宏脚本（XMBC 语法），例如 {LMBD}{WAITMS:120}{RMB}…",
            "在此貼上或輸入巨集腳本（XMBC 語法），例如 {LMBD}{WAITMS:120}{RMB}…"
        )
    }

    static var defaultHoldLabel: String {
        s("Default hold duration", "默认按住时长", "預設按住時長")
    }

    static var supportedTags: String {
        s(
            "Supported tags: {WAITMS:ms} {HOLDMS:ms} {LMB} {RMB} {MMB} {MB4} {MB5}, plus {LMBD}/{LMBU} for separate down/up; a plain character (e.g. s) is held for the {HOLDMS} duration.",
            "支持标签：{WAITMS:毫秒} {HOLDMS:毫秒} {LMB} {RMB} {MMB} {MB4} {MB5} 以及 {LMBD}/{LMBU} 等单独按下/抬起；普通字符（如 s）按 {HOLDMS} 指定时长按下。",
            "支援標籤：{WAITMS:毫秒} {HOLDMS:毫秒} {LMB} {RMB} {MMB} {MB4} {MB5} 以及 {LMBD}/{LMBU} 等單獨按下/抬起；一般字元（如 s）按 {HOLDMS} 指定時長按下。"
        )
    }

    static func deleteConfirmTitle(name: String) -> String {
        switch resolved {
        case .en: return "Delete script “\(name)”?"
        case .zhHans: return "删除脚本「\(name)」？"
        case .zhHant: return "刪除腳本「\(name)」？"
        case .system: return "删除脚本「\(name)」？"
        }
    }

    static var deleteConfirmWarning: String {
        s("This cannot be undone.", "删除后无法恢复。", "刪除後無法復原。")
    }

    static var newScript: String { s("New Script", "新脚本", "新腳本") }

    static var defaultScript: String { s("Default Script", "默认脚本", "預設腳本") }

    static var copySuffix: String { s(" copy", " 副本", " 副本") }

    static var unnamedScript: String { s("Untitled", "未命名", "未命名") }

    static var addButton: String { s("New", "新建", "新增") }

    static var duplicateButton: String { s("Duplicate", "复制", "複製") }

    static var deleteButton: String { s("Delete", "删除", "刪除") }

    static var cancelButton: String { s("Cancel", "取消", "取消") }

    static var nameLabel: String { s("Name", "名称", "名稱") }

    static var saveButton: String { s("Save", "保存", "儲存") }

    static var syntaxOk: String { s("Syntax OK", "语法检查通过", "語法檢查通過") }

    static var resetTemplateButton: String {
        s("Reset to Template", "重置为模板", "重設為範本")
    }

    static func parsedInfo(count: Int, duration: String) -> String {
        switch resolved {
        case .en: return "\(count) events · about \(duration)"
        case .zhHans: return "已解析 \(count) 个事件 · 约 \(duration)"
        case .zhHant: return "已解析 \(count) 個事件 · 約 \(duration)"
        case .system: return "已解析 \(count) 个事件 · 约 \(duration)"
        }
    }

    static func autoSaved(at text: String) -> String {
        switch resolved {
        case .en: return "Auto-saved \(text)"
        case .zhHans: return "已自动保存 \(text)"
        case .zhHant: return "已自動儲存 \(text)"
        case .system: return "已自动保存 \(text)"
        }
    }

    static func scriptSummary(count: Int, duration: String) -> String {
        switch resolved {
        case .en: return "\(count) events · \(duration)"
        case .zhHans: return "\(count) 个事件 · \(duration)"
        case .zhHant: return "\(count) 個事件 · \(duration)"
        case .system: return "\(count) 个事件 · \(duration)"
        }
    }

    static var parseFailed: String { s("Parse failed", "解析失败", "解析失敗") }

    // MARK: - 监听消息

    static var waitingForAccessibility: String {
        s("Waiting for Accessibility permission…", "等待「辅助功能」权限…", "等待「輔助功能」權限…")
    }

    static var listeningIntercepting: String {
        s(
            "Listening (side-button events intercepted)",
            "监听中（侧键事件已拦截）",
            "監聽中（側鍵事件已攔截）"
        )
    }

    static var listeningPassing: String {
        s(
            "Listening (side-button events passed through)",
            "监听中（侧键事件放行）",
            "監聽中（側鍵事件放行）"
        )
    }

    static var tapCreateFailed: String {
        s(
            "Could not create the mouse event listener. Check that Accessibility permission is granted.",
            "无法创建鼠标事件监听，请确认已授予「輔助功能」权限。",
            "無法建立滑鼠事件監聽，請確認已授予「輔助功能」權限。"
        )
    }

    // MARK: - 侧键选项

    static func sideButtonTitle(_ button: SideButton) -> String {
        switch button {
        case .button4:
            return s("Side Button 1 (button 4)", "侧键 1（按钮4）", "側鍵 1（按鈕4）")
        case .button5:
            return s("Side Button 2 (button 5)", "侧键 2（按钮5）", "側鍵 2（按鈕5）")
        case .both:
            return s("Either side button", "两个侧键都可触发", "兩個側鍵都可觸發")
        }
    }

    // MARK: - 鼠标键名

    static var mouseLeft: String { s("Left", "左键", "左鍵") }
    static var mouseRight: String { s("Right", "右键", "右鍵") }
    static var mouseMiddle: String { s("Middle", "中键", "中鍵") }
    static var mouseButton4: String { s("Button 4", "侧键4", "側鍵4") }
    static var mouseButton5: String { s("Button 5", "侧键5", "側鍵5") }

    // MARK: - 时长

    static func durationUnderMinute(_ seconds: Double) -> String {
        String(format: s("%.2f s", "%.2f 秒", "%.2f 秒"), seconds)
    }

    static func durationOverMinute(_ minutes: Double, _ seconds: Double) -> String {
        String(format: s("%.1f min %.1f s", "%.1f 分 %.1f 秒", "%.1f 分 %.1f 秒"),
               minutes, seconds)
    }

    // MARK: - 解析错误

    static var errEmpty: String { s("Macro is empty.", "宏内容为空。", "巨集內容為空。") }

    static var errUnclosedTag: String {
        s("Tag is missing a closing `}`.", "标签没有闭合的 `}`。", "標籤沒有閉合的 `}`。")
    }

    static func errInvalidTag(_ tag: String) -> String {
        switch resolved {
        case .en: return "Unknown tag: {\(tag)}"
        case .zhHans: return "无法识别的标签: {\(tag)}"
        case .zhHant: return "無法識別的標籤: {\(tag)}"
        case .system: return "无法识别的标签: {\(tag)}"
        }
    }

    static func errMissingArgument(_ tag: String) -> String {
        switch resolved {
        case .en: return "Tag is missing an argument: {\(tag)}"
        case .zhHans: return "标签缺少参数: {\(tag)}"
        case .zhHant: return "標籤缺少參數: {\(tag)}"
        case .system: return "标签缺少参数: {\(tag)}"
        }
    }

    static func errInvalidArgument(_ tag: String) -> String {
        switch resolved {
        case .en: return "Invalid argument: {\(tag)}"
        case .zhHans: return "参数不合法: {\(tag)}"
        case .zhHant: return "參數不合法: {\(tag)}"
        case .system: return "参数不合法: {\(tag)}"
        }
    }

    static func errUnsupportedKey(_ key: String) -> String {
        switch resolved {
        case .en: return "Unsupported key: \(key)"
        case .zhHans: return "不支持的按键: \(key)"
        case .zhHant: return "不支援的按鍵: \(key)"
        case .system: return "不支持的按键: \(key)"
        }
    }
}
