#!/bin/bash
#
# 卸载汉化：移除语言包、恢复 Info.plist、卸载自动恢复守护。
#
# 注意：原厂的 Developer ID 签名无法还原（重签过程是单向的）。
#       如果希望拿回一个「和官方一模一样」的 App，请从官方 Release 重新下载。
#
set -uo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  for cand in "/Applications/Compositor.app" "$HOME/Applications/Compositor.app"; do
    [ -d "$cand" ] && TARGET="$cand" && break
  done
fi
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "❌ 找不到 Compositor.app，请把路径作为参数传入。"
  exit 1
fi

echo "==> 目标 App：$TARGET"

if pgrep -x "Compositor" >/dev/null 2>&1; then
  echo "==> 退出 Compositor…"
  osascript -e 'tell application "Compositor" to quit' >/dev/null 2>&1
  sleep 1
  pkill -x "Compositor" >/dev/null 2>&1
fi

echo "==> 卸载自动恢复守护"
launchctl bootout "gui/$UID/com.wonderassembly.compositor.hanhua" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.wonderassembly.compositor.hanhua.plist"
rm -rf "$HOME/Library/Application Support/CompositorHanhua"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> 移除语言包"
rm -rf "$TARGET/Contents/Resources/zh-Hans.lproj"

echo "==> 恢复 CFBundleDevelopmentRegion = en"
plutil -replace CFBundleDevelopmentRegion -string en "$TARGET/Contents/Info.plist"
plutil -remove CFBundleAllowMixedLocalizations "$TARGET/Contents/Info.plist" 2>/dev/null || true

echo "==> 重新 ad-hoc 签名（否则签名不匹配会被系统杀掉）"
if codesign -d --entitlements :- "$TARGET" > "$TMP_DIR/ents.plist" 2>/dev/null && [ -s "$TMP_DIR/ents.plist" ]; then
  codesign --force --sign - --entitlements "$TMP_DIR/ents.plist" "$TARGET"
else
  codesign --force --sign - "$TARGET"
fi
xattr -cr "$TARGET" 2>/dev/null || true
codesign --verify --deep --strict "$TARGET" && echo "   ✅ 签名校验通过"

echo
echo "✅ 已移除汉化，App 已恢复为英文界面。"
echo "   想拿回完全原厂的签名，请到官方 Release 重新下载覆盖。"
