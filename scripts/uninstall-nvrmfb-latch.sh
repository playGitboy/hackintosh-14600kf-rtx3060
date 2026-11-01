#!/bin/bash
# 卸载「开机设置 flip_latch=2」，恢复驱动默认值 1
# 用法: sudo ./uninstall-nvrmfb-latch.sh
set -u

LABEL="local.nvrmfb-latch"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
HELPER="/usr/local/bin/nvrmfb-latch.sh"

[ "$(id -u)" -eq 0 ] || { echo "需要 root：sudo $0"; exit 1; }

launchctl bootout system/"$LABEL" 2>/dev/null || true
rm -f "$PLIST" "$HELPER"
echo "已移除 LaunchDaemon 与辅助脚本"

sysctl -w debug.nvrmfb_flip_latch=1 2>/dev/null || true
echo "当前值: $(sysctl -n debug.nvrmfb_flip_latch 2>/dev/null || echo '不可用')"
echo "完成。重启后即为驱动默认值。"
