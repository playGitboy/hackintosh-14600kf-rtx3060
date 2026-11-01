#!/bin/bash
# status.sh —— 黑苹果只读体检
#
# 用法：  ./status.sh            # 全部
#         ./status.sh gpu        # 只看显卡
#         ./status.sh audio      # 只看音频
#         ./status.sh net        # 只看网络/蓝牙
#         ./status.sh cpu        # 只看 CPU/电源
#
# 只读：不修改任何文件、不写 NVRAM、不需要 root。

set -u

SEC="${1:-all}"

hr() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
row() { printf '  %-22s %s\n' "$1" "$2"; }

need() { [ "$SEC" = "all" ] || [ "$SEC" = "$1" ]; }

if need sys; then
  hr "系统"
  row "macOS" "$(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  row "架构" "$(uname -m)"
  row "机型" "$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Identifier/{print $2; exit}')"
  row "SIP" "$(csrutil status 2>/dev/null | head -1 | sed 's/System Integrity Protection status: //')"
  row "boot-args" "$(nvram boot-args 2>/dev/null | sed 's/^boot-args[[:space:]]*//')"
fi

if need cpu; then
  hr "CPU / 拓扑"
  row "型号" "$(sysctl -n machdep.cpu.brand_string)"
  row "ncpu / physical / logical" "$(sysctl -n hw.ncpu) / $(sysctl -n hw.physicalcpu) / $(sysctl -n hw.logicalcpu)"
  row "plugin-type" "$(ioreg -l 2>/dev/null | grep -o 'plugin-type[^,}]*' | head -1)"
  row "传感器" "$(kmutil showloaded --list-only 2>/dev/null | grep -cE 'SMCProcessor|SMCSuperIO') 个 kext"
  hr "电源"
  pmset -g custom 2>/dev/null | grep -E '^\s*(sleep|displaysleep|hibernatemode|powernap|autopoweroff)' | sed 's/^/  /'
fi

if need gpu; then
  hr "显卡"
  row "芯片" "$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model/{print $2; exit}')"
  row "Metal" "$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Metal Support/{print $2; exit}')"
  row "VRAM" "$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/VRAM \(Total\)/{print $2; exit}')"
  system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Resolution|UI Looks like/{print "  " $0}'
  row "NullMoth kext" "$(kmutil showloaded --list-only 2>/dev/null | grep -cE "com\\.nullmoth\\.(NVRM|NVAccel|NVRMFB|NVRMAGDC)") / 4"
  row "bar1" "$(ioreg -l 2>/dev/null | grep -o "\"bar1-mb\"[^,}]*" | head -1)"
  hr "HiDPI override"
  if [ -d /Library/Displays/Contents/Resources/Overrides ]; then
    find /Library/Displays/Contents/Resources/Overrides -name 'DisplayProductID-*' -maxdepth 2 2>/dev/null | sed 's/^/  /'
  else
    echo "  （无 override 目录）"
  fi
fi

if need audio; then
  hr "音频"
  system_profiler SPAudioDataType 2>/dev/null | grep -E '^\s{8}[^ ].*:$|Default Output Device|Transport:|Output Source:' | sed 's/^/  /'
  row "NMHDA" "$(kmutil showloaded --list-only 2>/dev/null | grep -c 'com.nullmoth.NMHDA') 个"
fi

if need net; then
  hr "网络接口"
  networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port|Device:/{print "  " $0}'
  hr "Wi-Fi"
  row "en1 电源" "$(networksetup -getairportpower en1 2>&1)"
  hr "有线"
  ifconfig en0 2>/dev/null | grep -E 'status|media' | sed 's/^/  /'
  hr "蓝牙"
  system_profiler SPBluetoothDataType 2>/dev/null | grep -E 'Address|State:|Chipset:|Transport:|Firmware' | head -6 | sed 's/^/  /'
  row "BT daemon" "$(launchctl print system/local.bt-priority 2>/dev/null | awk -F'= ' '/state =/{print $2; exit}')"
fi

if need kext; then
  hr "关键 kext"
  kmutil showloaded --list-only 2>/dev/null | grep -Ei 'lilu|virtualsmc|applealc|whatevergreen|cpucp|cputopology|airportrtw|bluetool|realtekbluetooth|rtl812|luc|usbtoolbox|nmhda|nullmoth' | sed 's/^.*  //' | sed 's/^/  /'
fi

echo
echo "提示：这个脚本只读。修改任何配置前先备份 EFI。"
