#!/bin/bash
# 卸载「开机自动关闭 Wi-Fi（蓝牙优先）」，恢复开机默认开 Wi-Fi
# 用法: sudo ./卸载开机自动关WiFi.sh
set -u

LABEL="local.bt-priority"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
HELPER="/usr/local/bin/bt-priority.sh"

[ "$(id -u)" -eq 0 ] || { echo "需要 root：sudo $0"; exit 1; }

echo "[1/3] 停止并移除 LaunchDaemon"
launchctl bootout system/"$LABEL" 2>/dev/null || true
rm -f "$PLIST"
echo "  已删除 $PLIST"

echo "[2/3] 删除辅助脚本"
rm -f "$HELPER"
echo "  已删除 $HELPER"

echo "[3/3] 恢复 Wi-Fi"
networksetup -setairportpower en1 on 2>&1
networksetup -getairportpower en1

echo
echo "完成。下次开机会正常打开 Wi-Fi（蓝牙可能因共存问题再次断流）。"
