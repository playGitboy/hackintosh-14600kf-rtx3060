#!/bin/bash
# 安装「开机设置 debug.nvrmfb_flip_latch=2」
# 用法: sudo ./install-nvrmfb-latch.sh
set -eu

LABEL="local.nvrmfb-latch"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
HELPER="/usr/local/bin/nvrmfb-latch.sh"
SRC="$(cd "$(dirname "$0")" && pwd)"

[ "$(id -u)" -eq 0 ] || { echo "需要 root：sudo $0"; exit 1; }

echo "[1/3] 安装辅助脚本 -> $HELPER"
mkdir -p /usr/local/bin
cp "$SRC/nvrmfb-latch.sh" "$HELPER"
chown root:wheel "$HELPER"
chmod 755 "$HELPER"

echo "[2/3] 写入 LaunchDaemon -> $PLIST"
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
    <string>/var/log/nvrmfb-latch.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/nvrmfb-latch.log</string>
</dict>
</plist>
EOF
chown root:wheel "$PLIST"
chmod 644 "$PLIST"
plutil -lint "$PLIST"

echo "[3/3] 注册并立即执行"
launchctl bootout system/"$LABEL" 2>/dev/null || true
launchctl bootstrap system "$PLIST"
launchctl enable system/"$LABEL"

sleep 3
echo
echo "当前值: $(sysctl -n debug.nvrmfb_flip_latch 2>/dev/null || echo '不可用')"
echo "日志: /var/log/nvrmfb-latch.log"
echo "卸载: sudo ./uninstall-nvrmfb-latch.sh"
