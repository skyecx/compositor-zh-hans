#!/bin/bash
#
# 双击运行：汉化 + 安装「更新后自动恢复」守护
#
set -uo pipefail
cd "$(dirname "$0")" || exit 1

echo "════════ 第 1 步 / 共 2 步：汉化 Compositor ════════"
bash ./汉化.sh "$@"
rc=$?
if [ $rc -ne 0 ]; then
  echo
  echo "❌ 汉化失败（退出码 $rc），已中止。"
  echo "   按回车键关闭窗口。"
  read -r _
  exit $rc
fi

echo
echo "════════ 第 2 步 / 共 2 步：安装自动恢复守护 ════════"
bash ./安装自动恢复.command
rc=$?

echo
if [ $rc -eq 0 ]; then
  echo "🎉 全部完成，现在可以直接打开 Compositor 使用了。"
  echo "   以后 App 自动更新后，汉化会被自动装回来，无需手动操作。"
else
  echo "⚠️  汉化完成，但守护安装失败（退出码 $rc）。不影响本次使用，"
  echo "   只是 App 更新后需要重新双击本脚本一次。"
fi
echo "   按回车键关闭窗口。"
read -r _
exit $rc
