#!/bin/bash
# 安装「开机自动关闭 Wi-Fi（蓝牙优先）」
# 用法: sudo ./安装开机自动关WiFi.sh
set -eu

LABEL="local.bt-priority"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
HELPER="/usr/local/bin/bt-priority.sh"
SRC="$(cd "$(dirname "$0")" && pwd)"

[ "$(id -u)" -eq 0 ] || { echo "需要 root：sudo $0"; exit 1; }

echo "[1/4] 安装辅助脚本 -> $HELPER"
mkdir -p /usr/local/bin
cp "$SRC/bt-priority.sh" "$HELPER"
chown root:wheel "$HELPER"
chmod 755 "$HELPER"

echo "[2/4] 写入 LaunchDaemon -> $PLIST"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$HELPER</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>StandardOutPath</key>
    <string>/var/log/bt-priority.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/bt-priority.log</string>
</dict>
</plist>
EOF
chown root:wheel "$PLIST"
chmod 644 "$PLIST"
plutil -lint "$PLIST"

echo "[3/4] 注册并立即启动"
launchctl bootout system/"$LABEL" 2>/dev/null || true
launchctl bootstrap system "$PLIST"
launchctl enable system/"$LABEL"

echo "[4/4] 当前状态"
sleep 2
launchctl print system/"$LABEL" 2>/dev/null | grep -E "state|last exit" || true
networksetup -getairportpower en1

echo
echo "完成。开机后会自动关闭 en1（Wi-Fi），蓝牙优先。"
echo "日志: /var/log/bt-priority.log"
echo "卸载: sudo ./卸载开机自动关WiFi.sh"
