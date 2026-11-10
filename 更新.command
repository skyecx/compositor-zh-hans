#!/bin/bash
#
# 双击运行：检查更新 → 下载官方 DMG → 替换 App → 重新汉化 → 打开
#
# 汉化版的应用内「检查更新…」装不上新版本（ad-hoc 签名丢掉 Team ID，
# Sparkle 的安装器 XPC 服务会拒绝连接），所以以后更新请用这个脚本。
#
set -uo pipefail
cd "$(dirname "$0")" || exit 1

bash ./更新.sh "$@"
rc=$?

echo
echo "   按回车键关闭窗口。"
read -r _
exit $rc
