#!/bin/bash
#
# Compositor 一键更新 + 重新汉化
# ------------------------------------------------------------------
# 为什么需要这个脚本？
#   汉化必须改 App 包内容并 **ad-hoc 重签**，而 ad-hoc 签名没有 Team ID。
#   Sparkle 的安装器 XPC 服务（org.sparkle-project.InstallerLauncher）要求
#   客户端签名满足 `anchor apple generic and certificate leaf[subject.OU] = "3E4X3B9Z9T"`，
#   重签后这一步必然被拒（日志：Received message forbidden due to code signing requirement），
#   所以**汉化版点「检查更新…」永远装不上**。这不是脚本 bug，是签名链决定的。
#
#   本脚本把「下载官方 DMG → 整包替换 → 重新汉化 → 重开 App」一次做完。
#
# 用法：
#   bash 更新.sh             # 检查并更新到最新版
#   bash 更新.sh --check     # 只看当前版本 / 最新版本，不改动
#   bash 更新.sh --force     # 即使版本相同也重装一遍
#   bash 更新.sh /path/to/Compositor.app
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHER="$SCRIPT_DIR/汉化.sh"
FEED="https://raw.githubusercontent.com/robbietilton/Compositor/main/appcast.xml"

CHECK_ONLY=0
FORCE=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --check|-c) CHECK_ONLY=1 ;;
    --force|-f) FORCE=1 ;;
    -*) echo "未知参数：$arg"; exit 2 ;;
    *) TARGET="$arg" ;;
  esac
done

if [ -z "$TARGET" ]; then
  for cand in "/Applications/Compositor.app" "$HOME/Applications/Compositor.app"; do
    [ -d "$cand" ] && TARGET="$cand" && break
  done
fi
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "❌ 找不到 Compositor.app，请把 App 路径作为参数传入："
  echo "   bash 更新.sh /Applications/Compositor.app"
  exit 1
fi
TARGET="${TARGET%/}"

info() { /usr/libexec/PlistBuddy -c "Print :$1" "$TARGET/Contents/Info.plist" 2>/dev/null; }
CUR_VER="$(info CFBundleShortVersionString)"
CUR_BUILD="$(info CFBundleVersion)"
echo "==> 已安装：$TARGET"
echo "    版本：${CUR_VER:-?} (${CUR_BUILD:-?})"

# ---------- 查询上游最新版 ----------
echo "==> 查询上游最新版本…"
FEED_XML="$(curl -fsSL --max-time 20 "$FEED" 2>/dev/null)" || {
  echo "❌ 拉取 appcast 失败，请检查网络：$FEED"; exit 1
}
LATEST_VER="$(printf '%s' "$FEED_XML" | tr -d '\n' \
  | grep -o '<sparkle:shortVersionString>[^<]*' | head -1 | sed 's/.*>//')"
DMG_URL="$(printf '%s' "$FEED_XML" | tr -d '\n' \
  | grep -o 'url="[^"]*\.dmg"' | head -1 | sed 's/^url="//; s/"$//')"
if [ -z "$LATEST_VER" ] || [ -z "$DMG_URL" ]; then
  echo "❌ 解析 appcast 失败（版本或下载地址为空）"; exit 1
fi
echo "    上游最新：$LATEST_VER"
echo "    安装包：  $DMG_URL"

ver_gt() { # $1 > $2 ?
  [ "$1" = "$2" ] && return 1
  local IFS=. i x y
  local -a a b
  read -r -a a <<< "$1"
  read -r -a b <<< "$2"
  for i in 0 1 2 3; do
    x="${a[$i]:-0}"; y="${b[$i]:-0}"
    x="${x//[^0-9]/}"; y="${y//[^0-9]/}"
    x="${x:-0}"; y="${y:-0}"
    [ "$x" -gt "$y" ] && return 0
    [ "$x" -lt "$y" ] && return 1
  done
  return 1
}

if [ "$FORCE" -eq 0 ] && ! ver_gt "$LATEST_VER" "$CUR_VER"; then
  if [ "$LATEST_VER" = "$CUR_VER" ]; then
    echo "✅ 已是最新版（${CUR_VER}）。"
  else
    echo "⚠️  本机版本（${CUR_VER}）比上游 appcast 还新，未做改动。"
  fi
  [ "$CHECK_ONLY" -eq 1 ] && exit 0
  echo "   想强制重装：bash 更新.sh --force"
  exit 0
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "ℹ️  可更新：$CUR_VER → ${LATEST_VER}（--check 模式，未做改动）"
  exit 0
fi

# ---------- 下载 ----------
TMP_DIR="$(mktemp -d)"
MNT="$TMP_DIR/mnt"
cleanup() {
  hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "==> 下载安装包…"
DMG="$TMP_DIR/Compositor-$LATEST_VER.dmg"
if ! curl -fL --progress-bar --max-time 600 -o "$DMG" "$DMG_URL"; then
  echo "❌ 下载失败：$DMG_URL"; exit 1
fi
echo "    已下载：$(du -h "$DMG" | cut -f1)"

# ---------- 挂载并校验 ----------
echo "==> 挂载并校验…"
mkdir -p "$MNT"
hdiutil attach "$DMG" -nobrowse -quiet -mountpoint "$MNT" || {
  echo "❌ 挂载失败"; exit 1
}
SRC_APP="$MNT/Compositor.app"
if [ ! -d "$SRC_APP" ]; then
  echo "❌ 安装包里没有 Compositor.app"; exit 1
fi
NEW_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SRC_APP/Contents/Info.plist" 2>/dev/null)"
NEW_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SRC_APP/Contents/Info.plist" 2>/dev/null)"
echo "    安装包版本：${NEW_VER:-?} (${NEW_BUILD:-?})"
if [ "$NEW_VER" != "$LATEST_VER" ]; then
  echo "⚠️  安装包版本（${NEW_VER}）与 appcast（${LATEST_VER}）不一致，继续按安装包为准。"
fi

# 先复制到临时目录，确认能读再动旧 App
STAGE="$TMP_DIR/Compositor.app.new"
echo "==> 解包到临时目录…"
ditto "$SRC_APP" "$STAGE" || { echo "❌ 复制失败"; exit 1; }
[ -x "$STAGE/Contents/MacOS/Compositor" ] || { echo "❌ 安装包不完整（缺少主程序）"; exit 1; }

# ---------- 退出 App 并替换 ----------
if pgrep -x "Compositor" >/dev/null 2>&1; then
  echo "==> 退出正在运行的 Compositor…"
  osascript -e 'tell application "Compositor" to quit' >/dev/null 2>&1
  for _ in $(seq 1 20); do pgrep -x "Compositor" >/dev/null 2>&1 || break; sleep 0.5; done
  pkill -x "Compositor" >/dev/null 2>&1
fi

echo "==> 替换 $TARGET"
if ! rm -rf "$TARGET" 2>/dev/null; then
  echo "❌ 没有写入权限：$(dirname "$TARGET")"
  echo "   请在「系统设置 › 隐私与安全性 › App 管理」中允许终端访问。"
  exit 1
fi
if ! ditto "$STAGE" "$TARGET"; then
  echo "❌ 写入失败：$TARGET"
  exit 1
fi
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true

# ---------- 重新汉化 ----------
echo
echo "════════ 重新汉化 ════════"
if [ ! -f "$PATCHER" ]; then
  echo "⚠️  找不到 汉化.sh，跳过汉化（App 已是英文原版状态）。"
else
  bash "$PATCHER" "$TARGET" || echo "⚠️  汉化脚本返回非 0，请手动检查。"
fi

echo
echo "🎉 已更新到 $NEW_VER ($NEW_BUILD)。"
open "$TARGET" 2>/dev/null && echo "   已启动 Compositor。"
