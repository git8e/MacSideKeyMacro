#!/bin/bash
# 重新生成应用图标：SVG → PNG → 透明角处理 → iconset → AppIcon.icns
# qlmanage 渲染 SVG 时会垫不透明白底，必须用 fixalpha 裁掉圆角外的白边。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT_DIR/Resources/AppIcon.svg"
OUT="$ROOT_DIR/Resources/AppIcon.icns"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 圆角底板几何（须与 SVG 中的 <rect> 保持一致）
RECT_X=32; RECT_Y=32; RECT_W=960; RECT_H=960; RECT_R=224

echo "==> 渲染 SVG (1024px)"
qlmanage -t -s 1024 -o "$WORK" "$SVG" >/dev/null
RAW="$WORK/$(basename "$SVG").png"
[[ -f "$RAW" ]] || { echo "渲染失败: $RAW"; exit 1; }

echo "==> 裁掉圆角外的白底"
FIXED="$WORK/icon.png"
swift "$ROOT_DIR/Scripts/fixalpha.swift" "$RAW" "$FIXED" \
    "$RECT_X" "$RECT_Y" "$RECT_W" "$RECT_H" "$RECT_R"

echo "==> 生成 iconset"
SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"
gen() { sips -z "$1" "$1" "$FIXED" --out "$SET/icon_$2.png" >/dev/null; }
gen 16   16x16
gen 32   16x16@2x
gen 32   32x32
gen 64   32x32@2x
gen 128  128x128
gen 256  128x128@2x
gen 256  256x256
gen 512  256x256@2x
gen 512  512x512
gen 1024 512x512@2x

echo "==> 编译 .icns"
iconutil -c icns "$SET" -o "$OUT"
echo "OK: $OUT"
