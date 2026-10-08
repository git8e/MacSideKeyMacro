#!/bin/bash
# 构建 release 版并打包成 MacSideKeyMacro.app
# 用法: ./Scripts/package_app.sh [debug|release]   （默认 release）
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="MacSideKeyMacro"
EXEC_NAME="sidekey-macro"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_PATH="$ROOT_DIR/.build/$CONFIG/$EXEC_NAME"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"

cd "$ROOT_DIR"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

if [[ ! -f "$BIN_PATH" ]]; then
    echo "找不到可执行文件: $BIN_PATH" >&2
    exit 1
fi

echo "==> 打包 $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/$EXEC_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"

echo "==> ad-hoc 签名"
codesign --force --sign - "$APP_PATH"

echo "==> 校验"
codesign --verify --verbose=2 "$APP_PATH"
echo "OK: $APP_PATH"
