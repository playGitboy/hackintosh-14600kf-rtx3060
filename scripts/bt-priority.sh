#!/bin/bash
# 由 /Library/LaunchDaemons/local.bt-priority.plist 在开机时调用。
# 作用: 关闭 Wi-Fi，让蓝牙独享 2.4GHz 射频（本机 AirportRTW 不支持 BT 共存）。
IFACE="en1"
LOG="/var/log/bt-priority.log"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

log "--- boot: 开始 ---"

# 等 configd 把接口注册好（最多 60 秒）
for _ in $(seq 1 60); do
  networksetup -getairportpower "$IFACE" >/dev/null 2>&1 && break
  sleep 1
done

CUR=$(networksetup -getairportpower "$IFACE" 2>&1)
log "当前: $CUR"

if echo "$CUR" | grep -qi "Off"; then
  log "$IFACE 已是关闭状态，无需操作"
else
  if networksetup -setairportpower "$IFACE" off >>"$LOG" 2>&1; then
    log "已关闭 $IFACE"
  else
    log "networksetup 失败，回退 ifconfig down"
    ifconfig "$IFACE" down >>"$LOG" 2>&1 && log "ifconfig $IFACE down 成功"
  fi
fi

log "结果: $(networksetup -getairportpower "$IFACE" 2>&1)"
log "--- boot: 结束 ---"
