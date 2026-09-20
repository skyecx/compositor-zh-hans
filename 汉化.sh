#!/bin/bash
#
# Compositor 汉化外挂脚本（外部注入，不修改上游源码）
# ------------------------------------------------------------------
# 作用：
#   1. 把 zh-Hans.lproj/Localizable.strings 注入 App 包
#   2. 把 Info.plist 的 CFBundleDevelopmentRegion 改为 zh-Hans
#      （只放 .lproj 不够，必须改这一项，否则 preferredLocalizations 仍是 en）
#   3. 重新做 ad-hoc 签名（仅外层 App，不加 --deep、不加 --options runtime）
#   4. 清除 xattr（去掉 provenance / quarantine）
#
# 用法：
#   bash 汉化.sh                        # 自动找 /Applications/Compositor.app
#   bash 汉化.sh /path/to/Compositor.app
#   bash 汉化.sh --check                # 只检查状态，不修改
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STRINGS_SRC="$SCRIPT_DIR/zh-Hans.lproj/Localizable.strings"
DEVELOPMENT_REGION="zh-Hans"

CHECK_ONLY=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --check|-c) CHECK_ONLY=1 ;;
    -*) echo "未知参数：$arg"; exit 2 ;;
    *) TARGET="$arg" ;;
  esac
done

# ---------- 定位目标 App ----------
if [ -z "$TARGET" ]; then
  for cand in "/Applications/Compositor.app" "$HOME/Applications/Compositor.app"; do
    [ -d "$cand" ] && TARGET="$cand" && break
  done
fi
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "❌ 找不到 Compositor.app，请把 App 路径作为参数传入："
  echo "   bash 汉化.sh /Applications/Compositor.app"
  exit 1
fi
# 目标必须以 .app 结尾，否则 LaunchServices 会报 -10811
case "$TARGET" in
  *.app) ;;
  *) echo "❌ 目标路径必须以 .app 结尾：$TARGET"; exit 1 ;;
esac
TARGET="${TARGET%/}"

RES_DIR="$TARGET/Contents/Resources"
INFO_PLIST="$TARGET/Contents/Info.plist"

echo "==> 目标 App：$TARGET"
[ -d "$RES_DIR" ] || { echo "❌ 不是有效的 App 包（缺少 Contents/Resources）"; exit 1; }

# ---------- 当前状态 ----------
CUR_REGION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDevelopmentRegion' "$INFO_PLIST" 2>/dev/null || echo '(未设置)')"
CUR_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST" 2>/dev/null || echo '?')"
CUR_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" 2>/dev/null || echo '?')"
HAS_LPROJ=0
[ -f "$RES_DIR/zh-Hans.lproj/Localizable.strings" ] && HAS_LPROJ=1

echo "==> 当前版本：$CUR_VER ($CUR_BUILD)"
echo "==> 当前 CFBundleDevelopmentRegion：$CUR_REGION"
echo "==> 已有 zh-Hans.lproj：$([ $HAS_LPROJ -eq 1 ] && echo 是 || echo 否)"

if [ "$CUR_REGION" = "$DEVELOPMENT_REGION" ] && [ $HAS_LPROJ -eq 1 ]; then
  echo "✅ 已经汉化过，无需重复处理。"
  # 仍然检查签名是否完好（更新后 Sparkle 会用原厂签名覆盖）
  SIG="$(codesign -dv "$TARGET" 2>&1 | grep -E '^Signature=' || true)"
  echo "   签名：${SIG:-未知}"
  [ "$CHECK_ONLY" -eq 1 ] && exit 0
  # 已汉化但签名是 Developer ID（说明只被更新过没重签）→ 继续走重签流程
  case "$SIG" in
    *adhoc*) exit 0 ;;
  esac
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "ℹ️ 需要汉化（--check 模式，不做修改）"
  exit 1
fi

# ---------- 前置检查 ----------
if [ ! -f "$STRINGS_SRC" ]; then
  echo "❌ 找不到语言包：$STRINGS_SRC"
  echo "   请确保 zh-Hans.lproj/Localizable.strings 与本脚本在同一目录下。"
  exit 1
fi
if ! plutil -lint "$STRINGS_SRC" >/dev/null 2>&1; then
  echo "❌ 语言包语法错误，请先运行：plutil -lint '$STRINGS_SRC'"
  exit 1
fi

# 可写性检查（macOS 14+ 写 /Applications 需要「App 管理」权限）
if [ ! -w "$TARGET" ]; then
  echo "⚠️  没有写入权限：$TARGET"
  echo "   请在「系统设置 › 隐私与安全性 › App 管理」中允许终端访问，"
  echo "   或把 App 拷贝到你的用户目录后再汉化（例如 ~/Applications）。"
  exit 1
fi

# 正在运行则先退出
if pgrep -x "Compositor" >/dev/null 2>&1; then
  echo "==> Compositor 正在运行，先退出…"
  osascript -e 'tell application "Compositor" to quit' >/dev/null 2>&1
  for _ in $(seq 1 20); do pgrep -x "Compositor" >/dev/null 2>&1 || break; sleep 0.5; done
  pkill -x "Compositor" >/dev/null 2>&1
fi

# ---------- 1. 备份原始 entitlements ----------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
ENTS="$TMP_DIR/ents.plist"
if codesign -d --entitlements :- "$TARGET" > "$ENTS" 2>/dev/null && [ -s "$ENTS" ]; then
  echo "==> 已提取原始 entitlements"
else
  echo "⚠️  未取到 entitlements（将使用最小沙盒权限集）"
  cat > "$ENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.files.user-selected.read-write</key><true/>
  <key>com.apple.security.network.client</key><true/>
</dict></plist>
PLIST
fi

# ---------- 2. 注入语言包 ----------
echo "==> 注入 zh-Hans.lproj/Localizable.strings"
mkdir -p "$RES_DIR/zh-Hans.lproj"
cp -f "$STRINGS_SRC" "$RES_DIR/zh-Hans.lproj/Localizable.strings"
chmod 644 "$RES_DIR/zh-Hans.lproj/Localizable.strings"

# ---------- 3. 改 CFBundleDevelopmentRegion ----------
echo "==> 设置 CFBundleDevelopmentRegion = $DEVELOPMENT_REGION"
if ! plutil -replace CFBundleDevelopmentRegion -string "$DEVELOPMENT_REGION" "$INFO_PLIST"; then
  echo "❌ 修改 Info.plist 失败"; exit 1
fi
# 允许混合本地化（系统英文时也让 App 用中文，可选但更稳）
plutil -replace CFBundleAllowMixedLocalizations -bool true "$INFO_PLIST" 2>/dev/null || true

# ---------- 4. ad-hoc 重签（仅外层 App） ----------
echo "==> ad-hoc 重签（仅外层 App，不加 --deep / --options runtime）"
if ! codesign --force --sign - --entitlements "$ENTS" "$TARGET" 2>"$TMP_DIR/sign.err"; then
  echo "❌ 签名失败："; cat "$TMP_DIR/sign.err"; exit 1
fi

# ---------- 5. 清 xattr ----------
echo "==> 清除扩展属性"
xattr -cr "$TARGET" 2>/dev/null || true

# ---------- 6. 校验 ----------
echo "==> 校验签名"
if codesign --verify --deep --strict "$TARGET" 2>"$TMP_DIR/verify.err"; then
  echo "   ✅ 签名校验通过"
else
  echo "   ⚠️  校验有问题（通常仍可运行）："; sed 's/^/      /' "$TMP_DIR/verify.err"
fi
codesign -dv "$TARGET" 2>&1 | grep -E '^(Identifier|Signature|TeamIdentifier)=' | sed 's/^/   /'
echo "   大小：$(du -sh "$TARGET" | cut -f1)"

echo
echo "🎉 汉化完成。打开 App 后菜单/面板应为简体中文。"
echo "   若显示仍为英文，请执行：open -n '$TARGET'"
echo "   若被系统杀掉（秒退），说明签名被破坏，请重跑本脚本。"
