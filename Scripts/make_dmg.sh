#!/bin/bash
#
# 构建可分发的 DMG：经典的「拖进 Applications」布局 —— 左边是 App，右边是
# Applications 快捷方式，中间是箭头背景，并带自定义卷图标。
#
# 需要先打包好 .app（先跑 ./Scripts/package_app.sh，或直接传入路径）。
# Finder 布局是尽力而为：若终端没有控制 Finder 的权限，或 Finder 未运行，
# 仍然会产出 DMG（只是没有那张背景图）。
#
# 用法: Scripts/make_dmg.sh [path-to.app] [version]
#       默认: dist/MacSideKeyMacro.app 和 "1.0"

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/dist/MacSideKeyMacro.app}"
VERSION="${2:-1.0}"
APP_BUNDLE="$(basename "$APP")"          # 例如 MacSideKeyMacro.app
APP_NAME="${APP_BUNDLE%.app}"            # 例如 MacSideKeyMacro（用于文件名）
OUT="$ROOT/dist"
STAGE="$OUT/dmg-staging"
RW_DMG="$OUT/$APP_NAME-rw.dmg"
DMG="$OUT/$APP_NAME-$VERSION.dmg"
BG="$OUT/dmg-background.tiff"
VOLNAME="MacSideKeyMacro"

if [ ! -d "$APP" ]; then
    echo "error: 找不到 $APP，请先运行 './Scripts/package_app.sh'" >&2
    exit 1
fi

mkdir -p "$OUT"

echo "==> 绘制 DMG 背景"
swift "$ROOT/Scripts/make_dmg_background.swift" "$BG" >/dev/null

echo "==> 暂存 DMG 内容"
rm -rf "$STAGE"
mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/$APP_BUNDLE"
ln -s /Applications "$STAGE/Applications"
cp "$BG" "$STAGE/.background/background.tiff"

# 卷图标：复用 App 自带的图标。
if [ -f "$APP/Contents/Resources/AppIcon.icns" ]; then
    cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
else
    echo "warning: 未找到 $APP/Contents/Resources/AppIcon.icns，跳过卷图标。" >&2
fi

rm -f "$DMG" "$RW_DMG"

echo "==> 创建可写镜像"
hdiutil create -srcfolder "$STAGE" -volname "$VOLNAME" -fs HFS+ -format UDRW -ov "$RW_DMG" >/dev/null

MOUNTED=0
MOUNT=""
cleanup() {
    if [ "$MOUNTED" = "1" ] && [ -n "$MOUNT" ]; then
        hdiutil detach "$MOUNT" >/dev/null 2>&1 || hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
        MOUNTED=0
    fi
}
trap cleanup EXIT

# 带超时地运行命令（macOS 没有 `timeout`），避免 Finder 自动化授权弹窗把构建卡死。
run_with_timeout() {
    local secs="$1"; shift
    "$@" &
    local pid=$!
    local waited=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$waited" -ge "$secs" ]; then
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            kill -KILL "$pid" 2>/dev/null || true
            return 124
        fi
        sleep 1
        waited=$((waited + 1))
    done
    wait "$pid"
}

echo "==> 挂载镜像"
# 挂到默认的 /Volumes/<name>，这样 .DS_Store 里的卷内相对背景路径对任何人都有效。
hdiutil detach "/Volumes/$VOLNAME" >/dev/null 2>&1 || true
ATTACH_OUT="$(hdiutil attach "$RW_DMG" -nobrowse -readwrite)"
MOUNT="$(printf '%s\n' "$ATTACH_OUT" | awk '/Apple_HFS/{print substr($0, index($0,$3))}' | tail -1)"
if [ -z "$MOUNT" ] || [ ! -d "$MOUNT" ]; then
    echo "error: 无法挂载 $RW_DMG" >&2
    exit 1
fi
MOUNTED=1

APPLESCRIPT="$(mktemp)"
cat > "$APPLESCRIPT" <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 760, 548}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 120
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "$APP_BUNDLE" of container window to {165, 205}
        set position of item "Applications" of container window to {495, 205}
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

echo "==> 应用 Finder 布局（背景、图标位置）"
# 通过 Finder 设置 DMG 背景偶尔会失效（Finder 可能还没把背景别名写进
# .DS_Store），所以校验结果并重试几次。
layout_ok=0
for attempt in 1 2 3; do
    if run_with_timeout 20 osascript "$APPLESCRIPT" >/dev/null 2>&1; then
        sync
        sleep 1
        if strings "$MOUNT/.DS_Store" 2>/dev/null | grep -q "background.tiff"; then
            layout_ok=1
            break
        fi
    fi
    echo "    第 $attempt 次布局未生效，重试…"
    sleep 1
done
rm -f "$APPLESCRIPT"

if [ "$layout_ok" != "1" ]; then
    echo "warning: 未能应用 Finder 背景/图标布局（DMG 仍可正常使用）。" >&2
fi

# 自定义卷图标（需要 Xcode 命令行工具里的 SetFile）。
SetFile -a C "$MOUNT" >/dev/null 2>&1 || true

sync
sleep 1
cleanup
trap - EXIT

echo "==> 压缩为 $DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

rm -f "$RW_DMG"
rm -rf "$STAGE" "$BG"

echo "==> 完成: $DMG"
