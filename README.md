# MacSideKeyMacro

**按住鼠标侧键就自动执行的鼠标 + 键盘宏工具（macOS）。**

它的脚本语法**完全兼容 Windows 上的 X-Mouse Button Control（XMBC）** 的「Simulated Keystrokes（模拟按键）」写法，所以你在 XMBC 里写好的脚本可以原样粘贴过来直接用；如果你没见过 XMBC，也没关系 —— 只要把这段脚本当成一种「宏指令文本」照抄即可，下面是完整语法说明。

| 场景 | 说明 |
| --- | --- |
| 游戏连招 / 自动化操作 | 按住侧键循环执行，松开立刻停 |
| 从 Windows 迁移过来的宏脚本 | XMBC 脚本语法 1:1 兼容，直接粘贴 |
| 反复点按 / 组合键序列 | 脚本里写清每一次按下、抬起和毫秒级等待 |

## 特性

- **按住侧键触发**：默认「按住循环，松开停止」，松开瞬间中止并释放所有按键/鼠标键
  - 另可选：按一次执行一次 / 按住循环，松开跑完这一遍
- 可选侧键：按钮4（侧键1）、按钮5（侧键2）或两者都可；可选是否拦截侧键事件
- **脚本库**：支持多条脚本 —— 新建 / 复制 / 删除（带确认）/ 重命名，用下拉框切换
  - 编辑自动保存（防抖 0.35 秒），也可 Cmd+S 立即保存；重启后保留
  - 旧版单脚本配置会自动迁移成「默认脚本」
- **多语言界面**：简体中文 / 繁體中文 / English，默认跟随系统，可在「设置 → 语言」随时切换
- 实时解析并显示事件数与总时长，语法错误会直接标红提示
- 默认按住时长可调（未写 `{HOLDMS}` 时的按下持续时间）
- 手动「运行一次 / 停止」（Cmd+Enter）用于调时序

## 语言

「设置」卡片里的「语言」有四个选项：

| 选项 | 说明 |
| --- | --- |
| 跟随系统 / Follow System | 默认，按系统首选语言自动选择：`zh-Hant`/`zh-TW`/`zh-HK` → 繁中，其他 `zh` → 简中，其余 → English |
| 简体中文 | 强制简中 |
| 繁體中文 | 强制繁中 |
| English | 强制英文 |

切换立即生效（整窗重绘），并持久化到下次启动；「跟随系统」会在系统语言变化后于下次启动自动生效。

## 下载安装

1. 到 [Releases](../../releases) 下载最新的 `MacSideKeyMacro-macOS.zip`
2. 解压后把 `MacSideKeyMacro.app` 拖进「应用程序」
3. 首次打开：右键 App → 「打开」；如果提示「已损坏」，在终端执行：
   ```bash
   xattr -dr com.apple.quarantine /Applications/MacSideKeyMacro.app
   ```
4. 打开后在「设置 → 语言」里选语言（默认跟随系统）
5. **授权**：系统设置 → 隐私与安全性 → 辅助功能 → 「+」添加 `MacSideKeyMacro` 并勾选
6. 回到应用点「刷新状态」，绿点亮起后即可使用

> macOS 只对 App 做了 ad-hoc 签名（未购买开发者证书做公证），所以第 3 步是正常的。

## 从源码构建

```bash
git clone https://github.com/git8e/MacSideKeyMacro.git
cd MacSideKeyMacro
swift build            # 调试版
swift run sidekey-macro
```

打包成 `.app`（CI 也是这么做的）：

```bash
./Scripts/package_app.sh          # 产出 dist/MacSideKeyMacro.app
```

命令行自检（不启动界面，只验证解析器，CI 会跑）：

```bash
swift build -c release
.build/release/sidekey-macro --self-test
```

## 宏语法

| 写法 | 含义 |
| --- | --- |
| `{WAITMS:120}` | 等待 120 毫秒（`{WAIT:n}` 单位为秒） |
| `{HOLDMS:750}` | 让**下一个**按键/点击按住 750 毫秒（`{HOLD:n}` 单位为秒） |
| `{LMB}` `{RMB}` `{MMB}` `{MB4}` `{MB5}` | 完整点击：按下 → 按住 → 抬起 |
| `{LMBD}` `{LMBU}` | 单独按下 / 单独抬起（RMB/MMB/MB4/MB5 同理） |
| `s`、`=`、`,` 等普通字符 | 按一次该键（字母/数字/美式布局标点），按住时长取 `{HOLDMS}`，否则用「默认按住时长」 |
| `{VKC:24}` `{EXT:0}` | 直接发送原始虚拟键码（XMBC 兼容） |
| `{SHIFT}` `{CTRL}` `{ALT}` `{CMD}` | 修饰键，直到 `{CLEAR}` 才解除 |
| `{WAITMS:100-200}` | 随机等待 100~200 毫秒 |

举例 —— 按住左键 120ms、点一下右键、按住 `=` 键 750ms、再松开左键：

```
{LMBD}{WAITMS:120}{RMB}{HOLDMS:750}={WAITMS:350}{LMBU}
```

> 注意：`{` `}` 是标签定界符，无法作为按键输入（XMBC 同样如此），需要时请用 `{VKC:键码}`（`{` 是 33，`}` 是 30）。
> 标点按**美式键盘布局**映射，非美式布局下键位可能不同。

## 代码结构

```
Sources/SideKeyMacro/
├── SideKeyMacroApp.swift   入口 + AppDelegate（激活窗口、退出时兜底释放按键）
├── ContentView.swift       界面（权限/触发/手动控制/语言/脚本库）
├── Localization.swift      多语言文案（简中/繁中/英文 + 跟随系统）
├── AppModel.swift          脚本库、设置、权限、监听与触发接线、持久化
├── MacroScript.swift       可保存的脚本条目
├── MacroDSL.swift          宏脚本解析（XMBC 语法）
├── MacroTypes.swift        事件模型
├── MacroRunner.swift       执行器（绝对时间轴调度，漂移补偿，中止即释放）
├── SideKeyMonitor.swift    CGEventTap 监听侧键
├── ScriptTextView.swift    原生 NSTextView 编辑器（焦点稳定）
├── InputEmitter.swift      事件发送 + 按住状态注册表（进程退出兜底释放）
├── SelfTest.swift          命令行自检（--self-test）
├── KeyCodeMap.swift        按键名 ↔ CGKeyCode
├── Permissions.swift       权限查询
└── DefaultMacro.swift      默认宏脚本
Scripts/package_app.sh      打包 .app
.github/workflows/build.yml CI：构建 + 自检 + 打包 + 发 Release
```

## 故障排查

- **点进脚本框打不了字**：编辑框用的是原生 `NSTextView`，窗口激活后会自动把光标放进去；切换/新建脚本时也会自动聚焦。若仍无效，先确认应用窗口在最前。
- **辅助功能授权后仍监听不到侧键**：重新构建后二进制变了，需要在「辅助功能」里删掉旧条目再重新添加。
- **脚本里的 `-` 变成 `–`**：已关闭 macOS 的智能引号/破折号替换，一般不会再出现。
- **界面语言没变**：语言立即生效；若选「跟随系统」后系统语言变了，需重启应用。

## 注意

- 执行期间松开侧键会立刻取消当前任务，执行器会把本次按住的鼠标键和按键全部抬起，避免卡键。
- 进程被强杀时由 `atexit` 注册的兜底逻辑会释放所有按住的输入。
- 时序采用绝对时间轴（单调时钟 + 到点唤醒），不会因为每次注入的耗时累积漂移。

## 免责

本项目是独立实现，与 X-Mouse Button Control 及其作者无关联，仅兼容其脚本语法。请遵守你所玩游戏的用户协议，风险自负。

## License

MIT
