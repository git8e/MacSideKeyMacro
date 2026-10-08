import CoreGraphics
import Foundation

/// 线程安全的一次性标志：用于「松开侧键后跑完当前这一遍再停」。
private final class SharedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        value = false
        lock.unlock()
    }
}

@MainActor
final class MacroRunner {
    enum TriggerMode: String, CaseIterable, Identifiable {
        /// 按一次执行一次
        case once
        /// 按住循环，松开立即停止
        case holdLoop
        /// 按住循环，松开跑完当前这一遍
        case holdFinish

        var id: String { rawValue }

        var title: String { L10n.modeTitle(self) }

        var detail: String { L10n.modeDetail(self) }
    }

    /// 运行状态（不存文案，显示时再本地化）。
    enum Status: Equatable {
        case idle
        case stopped
        case runningLoop
        case runningOnce
        case emptyMacro

        var label: String {
            switch self {
            case .idle: return L10n.statusIdle
            case .stopped: return L10n.statusStopped
            case .runningLoop: return L10n.statusRunningLoop
            case .runningOnce: return L10n.statusRunningOnce
            case .emptyMacro: return L10n.statusEmptyMacro
            }
        }
    }

    /// (是否在运行, 状态)，始终在主线程回调。
    var onStateChange: (@MainActor (Bool, Status) -> Void)?

    private let releaseFlag = SharedFlag()
    private var runTask: Task<Void, Never>?
    private var runToken: UUID?

    func runOnce(items: [MacroItem]) {
        startInternal(items: items, loop: false)
    }

    func startHoldLoop(items: [MacroItem]) {
        startInternal(items: items, loop: true)
    }

    func sideKeyReleased(mode: TriggerMode) {
        switch mode {
        case .once:
            break
        case .holdLoop:
            stopAll()
        case .holdFinish:
            releaseFlag.set()
        }
    }

    func stopAll() {
        guard runTask != nil else { return }
        runToken = nil
        releaseFlag.set()
        runTask?.cancel()
        onStateChange?(false, .stopped)
    }

    private func startInternal(items: [MacroItem], loop: Bool) {
        guard !items.isEmpty else {
            onStateChange?(false, .emptyMacro)
            return
        }
        // 上一次运行（含清理）尚未结束时忽略新触发，避免两个执行器互相打架。
        guard runTask == nil else { return }

        releaseFlag.reset()
        HeldInputRegistry.shared.installExitHook()
        let token = UUID()
        runToken = token
        onStateChange?(true, loop ? .runningLoop : .runningOnce)

        let releaseFlag = self.releaseFlag
        let task = Task.detached(priority: .userInitiated) { [items, loop, token] in
            var exec = Executor()
            defer {
                exec.cleanup()
                Task { @MainActor in
                    self.finishRun(token: token)
                }
            }

            do {
                if loop {
                    while !Task.isCancelled {
                        try await exec.run(items: items)
                        if releaseFlag.isSet { break }
                    }
                } else {
                    try await exec.run(items: items)
                }
            } catch {
                // 被取消或执行失败：交给 defer 清理。
            }
        }
        runTask = task
    }

    private func finishRun(token: UUID) {
        let matched = runToken == token
        runTask = nil
        if matched {
            runToken = nil
            onStateChange?(false, .idle)
        } else {
            onStateChange?(false, .stopped)
        }
    }
}

// MARK: - 执行器

private struct Executor {
    private var pressedKeys: [CGKeyCode: UInt64] = [:]
    private var heldButtons: Set<MacroMouseButton> = []

    mutating func run(items: [MacroItem]) async throws {
        // 漂移补偿的绝对时间轴调度（不依赖累计 sleep，避免误差叠加）。
        var nextNs = DispatchTime.now().uptimeNanoseconds

        func sleepUntilNs(_ targetNs: UInt64) async throws {
            while true {
                let now = DispatchTime.now().uptimeNanoseconds
                if now >= targetNs { return }
                try await Task.sleep(nanoseconds: targetNs - now)
            }
        }

        for item in items {
            try Task.checkCancellation()

            let d = item.delaySeconds
            if d > 0 {
                nextNs = nextNs &+ UInt64(max(0, d) * 1_000_000_000)
                try await sleepUntilNs(nextNs)
            }

            try Task.checkCancellation()

            switch item.action {
            case .wait:
                break
            case .keyDown(let key):
                let code = CGKeyCode(key.code)
                pressedKeys[code] = key.flags
                HeldInputRegistry.shared.pressKey(code, flags: key.flags)
            case .keyUp(let key):
                let code = CGKeyCode(key.code)
                pressedKeys.removeValue(forKey: code)
                HeldInputRegistry.shared.releaseKey(code, flags: key.flags)
            case .mouseDown(let button):
                heldButtons.insert(button)
                HeldInputRegistry.shared.pressButton(button)
            case .mouseUp(let button):
                heldButtons.remove(button)
                HeldInputRegistry.shared.releaseButton(button)
            }
        }
    }

    /// 中止/结束时释放本次运行按住的所有输入。
    mutating func cleanup() {
        for button in heldButtons {
            HeldInputRegistry.shared.releaseButton(button)
        }
        heldButtons.removeAll(keepingCapacity: true)

        for (code, flags) in pressedKeys {
            HeldInputRegistry.shared.releaseKey(code, flags: flags)
        }
        pressedKeys.removeAll(keepingCapacity: true)
    }
}
