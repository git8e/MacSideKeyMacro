import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    // MARK: - 脚本库

    @Published private(set) var scripts: [MacroScript]

    @Published var selectedScriptID: UUID {
        didSet {
            reparse()
            scheduleSave()
        }
    }

    // MARK: - 全局设置

    @Published var triggerMode: MacroRunner.TriggerMode {
        didSet { scheduleSave() }
    }

    @Published var sideButton: SideButton {
        didSet { scheduleSave(); applyMonitor() }
    }

    @Published var interceptSideKey: Bool {
        didSet { scheduleSave(); applyMonitor() }
    }

    @Published var monitorEnabled: Bool {
        didSet {
            scheduleSave()
            if !monitorEnabled {
                // 关掉监听后不会再收到“松开侧键”，必须主动停下，否则宏会一直循环。
                runner.stopAll()
            }
            applyMonitor()
        }
    }

    /// 未标注 `{HOLDMS}` 时的默认按住时长。
    @Published var defaultHoldMs: Double {
        didSet { scheduleSave(); reparse() }
    }

    /// 界面语言（`.system` = 跟随系统）。改它会让整个 ContentView 重建，
    /// 于是所有 `L10n.xxx` 重新取值，界面即时切换。
    @Published var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            L10n.language = language
            refreshLocalizedStaticText()
        }
    }

    // MARK: - 运行状态

    @Published private(set) var isRunning = false
    @Published private(set) var status: MacroRunner.Status = .idle

    /// 显示用文案（随 `status` 与语言变化实时重算）。
    var statusText: String { status.label }
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var monitorMessage: String?
    @Published private(set) var parseError: String?
    @Published private(set) var itemCount = 0
    @Published private(set) var durationText = "—"
    @Published private(set) var lastSavedAt: Date?

    // MARK: - 依赖

    let runner = MacroRunner()
    private let monitor = SideKeyMonitor()
    private var items: [MacroItem] = []
    private var pendingSave: DispatchWorkItem?

    var selectedScript: MacroScript? {
        scripts.first(where: { $0.id == selectedScriptID })
    }

    // MARK: - 初始化

    private init() {
        let settings = AppModel.loadSettings()

        triggerMode = settings.triggerMode.flatMap { MacroRunner.TriggerMode(rawValue: $0) } ?? .holdLoop
        sideButton = settings.sideButton.flatMap { SideButton(rawValue: $0) } ?? .both
        interceptSideKey = settings.interceptSideKey ?? true
        monitorEnabled = settings.monitorEnabled ?? true
        defaultHoldMs = settings.defaultHoldMs ?? MacroDSL.defaultHoldMs
        language = L10n.language

        let loaded = AppModel.loadScripts()
        if loaded.scripts.isEmpty {
            // 从旧版单脚本配置迁移。
            let seed = MacroScript(
                name: L10n.defaultScript,
                text: settings.macroText ?? DefaultMacro.text
            )
            scripts = [seed]
            selectedScriptID = seed.id
        } else {
            scripts = loaded.scripts
            if let id = loaded.selectedScriptID, loaded.scripts.contains(where: { $0.id == id }) {
                selectedScriptID = id
            } else {
                selectedScriptID = loaded.scripts[0].id
            }
        }

        runner.onStateChange = { [weak self] running, newStatus in
            self?.isRunning = running
            self?.status = newStatus
        }

        monitor.onButtonDown = { [weak self] in
            Task { @MainActor in self?.handleSideKeyDown() }
        }
        monitor.onButtonUp = { [weak self] in
            Task { @MainActor in self?.handleSideKeyUp() }
        }

        reparse()
        refreshPermissions()
        applyMonitor()
    }

    // MARK: - 脚本增删改

    /// 修改当前脚本正文。
    func updateSelectedScriptText(_ text: String) {
        guard let idx = scripts.firstIndex(where: { $0.id == selectedScriptID }) else { return }
        guard scripts[idx].text != text else { return }
        scripts[idx].text = text
        scripts[idx].updatedAt = Date()
        reparse()
        scheduleSave()
    }

    func renameSelectedScript(_ name: String) {
        guard let idx = scripts.firstIndex(where: { $0.id == selectedScriptID }) else { return }
        guard scripts[idx].name != name else { return }
        scripts[idx].name = name
        scripts[idx].updatedAt = Date()
        scheduleSave()
    }

    /// 新建一个空脚本并选中它。
    func addScript() {
        let script = MacroScript(name: uniqueName(base: L10n.newScript), text: "")
        scripts.append(script)
        selectedScriptID = script.id
        scheduleSave()
    }

    /// 新建一个带默认模板的脚本并选中它。
    func addScriptFromTemplate() {
        let script = MacroScript(name: uniqueName(base: L10n.newScript), text: DefaultMacro.text)
        scripts.append(script)
        selectedScriptID = script.id
        scheduleSave()
    }

    func duplicateSelectedScript() {
        guard let current = selectedScript else { return }
        var copy = current
        copy.id = UUID()
        copy.name = uniqueName(base: current.name + L10n.copySuffix)
        copy.updatedAt = Date()
        scripts.append(copy)
        selectedScriptID = copy.id
        scheduleSave()
    }

    func deleteScript(id: UUID) {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts.remove(at: idx)

        if scripts.isEmpty {
            let fresh = MacroScript(name: L10n.defaultScript, text: DefaultMacro.text)
            scripts = [fresh]
            selectedScriptID = fresh.id
        } else if selectedScriptID == id {
            selectedScriptID = scripts[min(idx, scripts.count - 1)].id
        }
        scheduleSave()
    }

    /// 把当前脚本内容重置为内置模板。
    func resetSelectedScriptToTemplate() {
        updateSelectedScriptText(DefaultMacro.text)
    }

    /// 立即写盘（Cmd+S / 「保存」按钮）。
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        writeStateNow()
    }

    private func uniqueName(base: String) -> String {
        let existing = Set(scripts.map(\.name))
        if !existing.contains(base) { return base }
        var n = 2
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: - 触发

    private func handleSideKeyDown() {
        guard monitorEnabled, accessibilityGranted else { return }
        switch triggerMode {
        case .once:
            runner.runOnce(items: items)
        case .holdLoop, .holdFinish:
            runner.startHoldLoop(items: items)
        }
    }

    private func handleSideKeyUp() {
        guard monitorEnabled else { return }
        runner.sideKeyReleased(mode: triggerMode)
    }

    func runTest() {
        runner.runOnce(items: items)
    }

    func stop() {
        runner.stopAll()
    }

    // MARK: - 解析

    func reparse() {
        let text = selectedScript?.text ?? ""
        do {
            let parsed = try MacroDSL.parse(text, defaultHoldMs: defaultHoldMs)
            items = parsed
            itemCount = parsed.count
            durationText = MacroDSL.durationText(of: parsed)
            parseError = nil
        } catch {
            items = []
            itemCount = 0
            durationText = "—"
            parseError = error.localizedDescription
        }
    }

    // MARK: - 权限与监听

    func refreshPermissions() {
        let granted = Permissions.accessibilityStatus() == .granted
        // 无变化时不要写 @Published，否则每 2 秒都会让整棵视图刷新、编辑器焦点被清掉。
        guard granted != accessibilityGranted else { return }
        accessibilityGranted = granted
        if !granted {
            runner.stopAll()
        }
        applyMonitor()
    }

    func requestAccessibility() {
        Permissions.requestAccessibilityPrompt()
        refreshPermissions()
    }

    func applyMonitor() {
        guard monitorEnabled else {
            monitor.stop()
            monitorMessage = nil
            return
        }
        guard accessibilityGranted else {
            monitor.stop()
            monitorMessage = L10n.waitingForAccessibility
            return
        }
        do {
            try monitor.start(button: sideButton, intercept: interceptSideKey)
            monitorMessage = interceptSideKey
                ? L10n.listeningIntercepting
                : L10n.listeningPassing
        } catch {
            monitor.stop()
            monitorMessage = error.localizedDescription
        }
    }

    /// 语言切换后刷新不经过 SwiftUI 的静态文案（窗口标题等）。
    private func refreshLocalizedStaticText() {
        // 单窗口应用：直接给所有窗口换标题（场景标题不会随语言重建）。
        let title = L10n.appTitle
        NSApp.windows.forEach { $0.title = title }
        // 解析结果/监听消息都是取值时缓存的，切语言后按新语言重算。
        reparse()
        if monitorMessage != nil {
            applyMonitor()
        }
    }

    func shutdown() {
        runner.stopAll()
        monitor.stop()
        HeldInputRegistry.shared.releaseAll()
    }

    // MARK: - 持久化

    private struct PersistedSettings: Codable {
        /// 旧版单脚本配置遗留字段，仅用于迁移。
        var macroText: String? = nil
        var triggerMode: String? = nil
        var sideButton: String? = nil
        var interceptSideKey: Bool? = nil
        var monitorEnabled: Bool? = nil
        var defaultHoldMs: Double? = nil
    }

    private struct PersistedScripts: Codable {
        var scripts: [MacroScript]
        var selectedScriptID: UUID?
    }

    private static let settingsKey = "sidemacro.settings.v2"
    private static let legacySettingsKey = "sidemacro.settings.v1"
    private static let scriptsKey = "sidemacro.scripts.v1"

    private static func loadSettings() -> PersistedSettings {
        let defaults = UserDefaults.standard
        for key in [settingsKey, legacySettingsKey] {
            guard let data = defaults.data(forKey: key),
                  let value = try? JSONDecoder().decode(PersistedSettings.self, from: data) else { continue }
            return value
        }
        return PersistedSettings()
    }

    private static func loadScripts() -> PersistedScripts {
        guard let data = UserDefaults.standard.data(forKey: scriptsKey),
              let value = try? JSONDecoder().decode(PersistedScripts.self, from: data) else {
            return PersistedScripts(scripts: [], selectedScriptID: nil)
        }
        return value
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.writeStateNow()
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func writeStateNow() {
        let defaults = UserDefaults.standard

        let settings = PersistedSettings(
            triggerMode: triggerMode.rawValue,
            sideButton: sideButton.rawValue,
            interceptSideKey: interceptSideKey,
            monitorEnabled: monitorEnabled,
            defaultHoldMs: defaultHoldMs
        )
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: AppModel.settingsKey)
        }

        let scriptsState = PersistedScripts(scripts: scripts, selectedScriptID: selectedScriptID)
        if let data = try? JSONEncoder().encode(scriptsState) {
            defaults.set(data, forKey: AppModel.scriptsKey)
        }

        lastSavedAt = Date()
    }
}
