#!/bin/bash
#
# 汉化守护脚本 —— Sparkle 自动更新后自动重新打汉化补丁
# ------------------------------------------------------------------
# 原理：Sparkle 更新会整包替换 /Applications/Compositor.app，
#       刚注入的 zh-Hans.lproj 会被一并删除。本脚本由 LaunchAgent
#       通过 WatchPaths 在该目录发生变化时被唤醒，检测到“未汉化”
#       就自动重新注入 + 重签，用户无感。
#
# 用法（一般不用手动运行，由 LaunchAgent 调用）：
#   bash watchdog.sh [/Applications/Compositor.app]
#
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="${1:-/Applications/Compositor.app}"
PATCHER="$DIR/汉化.sh"
LOG="$HOME/Library/Logs/compositor-hanhua.log"

log() { echo "[$(date '+%F %T')] $*" >> "$LOG" 2>/dev/null; }

log "── watchdog 启动，目标：$APP"

if [ ! -d "$APP" ]; then
  log "目标不存在，退出"; exit 0
fi

# 先等 App 更新写入完成（避免在 Sparkle 半途替换时动手）
for _ in $(seq 1 20); do
  if [ -f "$APP/Contents/MacOS/Compositor" ] && [ -d "$APP/Contents/_CodeSignature" ]; then break; fi
  sleep 2
done

for i in $(seq 1 30); do
  # 已汉化 → 完成
  if bash "$PATCHER" --check "$APP" >/dev/null 2>&1; then
    log "检测到已汉化，无需处理"
    exit 0
  fi

  sleep 3
  log "第 $i 次尝试注入…"
  if bash "$PATCHER" "$APP" >> "$LOG" 2>&1; then
    if bash "$PATCHER" --check "$APP" >/dev/null 2>&1; then
      log "✅ 汉化已重新应用"
      exit 0
    fi
  fi
  log "本次未完成，继续重试…"
done

log "❌ 重试 30 次后仍失败，请手动运行：bash '$PATCHER' '$APP'"
exit 1
