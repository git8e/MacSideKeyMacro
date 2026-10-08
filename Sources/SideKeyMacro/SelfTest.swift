import Foundation

/// 命令行自检：`sidekey-macro --self-test`
/// 不启动界面，只验证宏解析器，供 CI 和排障使用。
enum SelfTest {
    static func run() -> Never {
        var failures = 0

        func check(_ name: String, _ body: () throws -> [MacroItem]) {
            do {
                let items = try body()
                print("[OK] \(name): \(items.count) 个事件, \(MacroDSL.durationText(of: items))")
            } catch {
                print("[FAIL] \(name): \(error.localizedDescription)")
                failures += 1
            }
        }

        check("内置默认脚本") { try MacroDSL.parse(DefaultMacro.text) }

        check("HOLDMS + 标点按键") {
            let items = try MacroDSL.parse("{LMBD}{WAITMS:120}{RMB}{HOLDMS:750}={WAITMS:350}{LMBU}")
            guard items.contains(where: {
                if case .keyDown(let k) = $0.action { return k.display == "=" }
                return false
            }) else {
                throw NSError(domain: "selftest", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "未生成 = 按键事件"
                ])
            }
            return items
        }

        check("VKC 原始键码") {
            let items = try MacroDSL.parse("{VKC:24}")
            guard items.count == 2 else {
                throw NSError(domain: "selftest", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "VKC 应展开为按下+抬起 2 个事件，实际 \(items.count)"
                ])
            }
            return items
        }

        check("连续 WAITMS 累加") {
            let items = try MacroDSL.parse("{WAITMS:180}{WAITMS:180}{LMBD}")
            let total = MacroDSL.durationSeconds(of: items)
            guard abs(total - 0.36) < 0.0001 else {
                throw NSError(domain: "selftest", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "两次 180ms 应合计 360ms，实际 \(total * 1000)ms"
                ])
            }
            return items
        }

        func expectError(_ name: String, _ body: () throws -> [MacroItem]) {
            do {
                _ = try body()
                print("[FAIL] \(name): 非法脚本没有报错")
                failures += 1
            } catch {
                print("[OK] \(name): \(error.localizedDescription)")
            }
        }

        expectError("非法标签应报错") {
            try MacroDSL.parse("{NOT_A_TAG}")
        }

        // MARK: 多语言

        func checkValue(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
            if ok {
                print("[OK] \(name)")
            } else {
                print("[FAIL] \(name): \(detail())")
                failures += 1
            }
        }

        let originalLanguage = L10n.language
        L10n.language = .en
        let en = L10n.cardPermission
        L10n.language = .zhHans
        let hans = L10n.cardPermission
        L10n.language = .zhHant
        let hant = L10n.cardPermission
        checkValue("语言包 EN/简/繁",
                   en == "Permissions" && hans == "权限" && hant == "權限",
                   "en=\(en) hans=\(hans) hant=\(hant)")
        checkValue("语言偏好可持久化",
                   { L10n.language = .zhHant; return L10n.language == .zhHant }(),
                   "写入后读回不一致")
        checkValue("状态文案随语言变化",
                   { L10n.language = .en; let a = L10n.statusIdle
                     L10n.language = .zhHans; let b = L10n.statusIdle
                     return a == "Idle" && b == "待机" }(),
                   "Idle/待机 未正确切换")
        L10n.language = .system
        checkValue("跟随系统可解析",
                   [AppLanguage.en, .zhHans, .zhHant, .system].allSatisfy {
                       L10n.languageOption($0).isEmpty == false
                   },
                   "存在空的语言选项")
        L10n.language = originalLanguage

        if failures > 0 {
            print("自检失败: \(failures) 项")
            exit(1)
        }
        print("自检通过")
        exit(0)
    }
}
