#!/bin/bash
# 开机把 NullMoth 的 flip latch 设为 deferred 模式（=2）。
#
# 背景：默认 =1 时，每次 present 都要等 flip 真正落到面板才返回，
#       实测本机每帧约 14 ms（60 Hz 一帧只有 16.7 ms）。
#       =2 改为在下一次 submit 时检查，厂商在 2.5.2 提供为 opt-in。
#       参考：nullmoth/nvidia-macos-driver#300
#
# 风险：厂商默认用 1 是为了压某些机器上的闪烁。若出现闪烁/撕裂，
#       把 /Library/LaunchDaemons/local.nvrmfb-latch.plist 删掉重启即可。

LOG="/var/log/nvrmfb-latch.log"
TARGET=2

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

log "--- boot: 等待 NVRM 加载 ---"

# 驱动加载前 sysctl 节点不存在，最多等 120 秒
for _ in $(seq 1 120); do
  if sysctl -n debug.nvrmfb_flip_latch >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! sysctl -n debug.nvrmfb_flip_latch >/dev/null 2>&1; then
  log "NVRM 未加载（没有 NVIDIA 驱动或启动失败），不处理"
  exit 0
fi

CUR=$(sysctl -n debug.nvrmfb_flip_latch 2>/dev/null)
log "当前 flip_latch=$CUR"

if [ "$CUR" = "$TARGET" ]; then
  log "已是 $TARGET，无需操作"
  exit 0
fi

if sysctl -w "debug.nvrmfb_flip_latch=$TARGET" >>"$LOG" 2>&1; then
  log "已设置为 $TARGET"
else
  log "设置失败（可能驱动版本不支持该节点）"
fi
