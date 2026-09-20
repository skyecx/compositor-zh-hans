#!/bin/bash
#
# 安装「更新后自动恢复汉化」守护（LaunchAgent）
# ------------------------------------------------------------------
# 做完这一步，Compositor 日后通过 Sparkle 自动更新时，
# 汉化会被自动重新补上，无需手动操作。
#
# 双击本文件即可；也可以命令行运行：bash 安装自动恢复.command
#
set -uo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPPORT="$HOME/Library/Application Support/CompositorHanhua"
AGENT_LABEL="com.wonderassembly.compositor.hanhua"
AGENT_PLIST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
LOG="$HOME/Library/Logs/compositor-hanhua.log"

APP=""
for cand in "/Applications/Compositor.app" "$HOME/Applications/Compositor.app"; do
  [ -d "$cand" ] && APP="$cand" && break
done
if [ -z "$APP" ]; then
  read -r -p "请输入 Compositor.app 的完整路径： " APP
fi
case "$APP" in
  *.app) ;;
  *) echo "❌ 路径必须以 .app 结尾：$APP"; exit 1 ;;
esac

echo "==> 安装目录：$SUPPORT"
mkdir -p "$SUPPORT" "$SUPPORT/zh-Hans.lproj" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp -f "$SRC_DIR/汉化.sh" "$SUPPORT/汉化.sh"
cp -f "$SRC_DIR/watchdog.sh" "$SUPPORT/watchdog.sh"
cp -f "$SRC_DIR/zh-Hans.lproj/Localizable.strings" "$SUPPORT/zh-Hans.lproj/Localizable.strings"
chmod +x "$SUPPORT/汉化.sh" "$SUPPORT/watchdog.sh"

echo "==> 写入 LaunchAgent：$AGENT_PLIST"
cat > "$AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SUPPORT/watchdog.sh</string>
    <string>$APP</string>
  </array>
  <!-- App 包或其所在目录发生变化（Sparkle 更新整包替换）时触发 -->
  <key>WatchPaths</key>
  <array>
    <string>$APP</string>
    <string>$(dirname "$APP")</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST

plutil -lint "$AGENT_PLIST" >/dev/null || { echo "❌ plist 语法错误"; exit 1; }

echo "==> 加载 LaunchAgent"
launchctl bootout "gui/$UID/$AGENT_LABEL" >/dev/null 2>&1 || true
if launchctl bootstrap "gui/$UID" "$AGENT_PLIST" 2>/dev/null; then
  echo "   ✅ 已加载"
else
  launchctl unload "$AGENT_PLIST" 2>/dev/null
  launchctl load -w "$AGENT_PLIST" 2>/dev/null && echo "   ✅ 已加载（旧接口）" || echo "   ⚠️ 加载失败，请重试或重启后生效"
fi
launchctl kickstart -k "gui/$UID/$AGENT_LABEL" >/dev/null 2>&1 || true

echo
echo "🎉 完成。"
echo "   监控路径：$APP"
echo "   日志文件：$LOG"
echo
echo "   先手动汉化一次：  bash \"$SUPPORT/汉化.sh\" \"$APP\""
echo "   卸载守护：        launchctl bootout gui/$UID/$AGENT_LABEL && rm \"$AGENT_PLIST\""
