# 11 驱动与工具下载清单

> 本机实际版本。重装时优先用「本机版本」；升级前先备份 EFI 和 `/Library/Extensions`。
> 全部链接为上游官方地址；国内直连不稳时加镜像前缀（见文末）。

## 1. 引导层

| 组件 | 本机版本 | 下载 |
|---|---|---|
| OpenCore | **1.0.9 DBG**（`DBG-109-2026-10-23`） | https://github.com/acidanthera/OpenCorePkg/releases |
| HfsPlus.efi | — | https://github.com/acidanthera/OcBinaryData/raw/master/Drivers/HfsPlus.efi |
| OpenRuntime / OpenCanopy / ResetNvramEntry | 随 OpenCore | OpenCorePkg 压缩包内 `EFI/OC/Drivers` |
| 每日构建（DBG） | — | https://dortania.github.io/builds/?product=OpenCorePkg&viewall=true |

> `OpenHfsPlus.efi` 与 `HfsPlus.efi` **只能启用一个**。

---

## 2. 核心 kext

| kext | 本机版本 | 作用 | 官方来源 |
|---|---|---|---|
| **Lilu** | 1.7.3 | 补丁加载器（所有 acidanthera kext 的基础） | https://github.com/acidanthera/Lilu/releases |
| **VirtualSMC** | 1.3.9 | SMC 模拟 | https://github.com/acidanthera/VirtualSMC/releases |
| SMCProcessor | 1.3.9 | CPU 传感器 | VirtualSMC 包内 |
| SMCSuperIO | 1.3.9 | 风扇/主板传感器 | VirtualSMC 包内 |
| **WhateverGreen** | 1.7.2 | 显卡通用补丁 | https://github.com/acidanthera/WhateverGreen/releases |
| **AppleALC** | 1.9.9 | 板载声卡 | https://github.com/acidanthera/AppleALC/releases |
| **RestrictEvents** | 1.1.7 | 屏蔽内存/CPU 提示 | https://github.com/acidanthera/RestrictEvents/releases |
| NVMeFix | 1.1.4 | NVMe 电源管理 | https://github.com/acidanthera/NVMeFix/releases |
| **AMFIPass** | 1.4.1 | AMFI 开启时加载未签名 kext | 原仓库已归档，用 OCLP 内置：https://github.com/dortania/OpenCore-Legacy-Patcher/raw/main/payloads/Kexts/Acidanthera/AMFIPass-v1.4.1-RELEASE.zip |
| **CpuTopologyRebuild** | 2.0.2 | P/E 核拓扑重建 | https://github.com/b00t0x/CpuTopologyRebuild/releases |

> 本机多数版本比官方 Release 高一位，来自 Dortania 每日构建（CI），不是正式版。想稳就用官方 Release。
> 每日构建入口：`https://dortania.github.io/builds/?product=<名字>&viewall=true`

---

## 3. 显卡

| 组件 | 版本 | 说明 |
|---|---|---|
| **NullMoth** | **2.6.4** | 官网 https://nullmothsystems.com/ |
| 安装器 | 2.6.4 | `1401.app`，随包提供 |
| NMHDA（HDMI 音频） | 1.0.0 | 随 NullMoth 2.6.x 提供，放 `EFI/OC/Kexts` |

**许可：PolyForm Noncommercial 1.0.0，禁止商用。** 本仓库不附带二进制，只给获取方式。

必需 boot-args：

```
nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth gfxrst=4 nvfbhidpi=1
```

---

## 4. 网络与蓝牙

| 组件 | 芯片 | 本机版本 | 下载 |
|---|---|---|---|
| **AirportRTW** | RTL8852BE（`10EC:C852`） | 2.2.1 | https://github.com/souissiak1-maker/AirportRTW/releases/download/V2.2.1/AirportRTW-Sequoia-Release.zip |
| **RealtekBluetoothFirmware** | 同卡蓝牙（USB） | 1.0.2 | https://github.com/thegwchr/RealtekBluetoothFirmware/releases/download/v1.0.2/RealtekBluetoothFirmware_v1.0.2_5080405E-068B-3F14-92D7-0F48AB51C52B.zip |
| **BlueToolFixup** | 蓝牙修复（macOS 12+） | 2.7.3 | https://github.com/acidanthera/BrcmPatchRAM/releases （RELEASE 包内含） |
| **RTL812xLucy** | RTL8125 2.5G 有线 | 1.1.100 | https://github.com/Mieze/RTL812xLucy/releases/download/v1.1.1/RTL812xLucy-V1.1.1.zip |

> **AirportRTW 必须按系统版本选包。** 同页还有 Monterey / Ventura / Sonoma 14.0 / Sonoma 14.4 / Sequoia / Tahoe。
> macOS 15（本机）用 `AirportRTW-Sequoia-Release.zip`。下错的表现是「kext 加载但接口不出现」。

蓝牙必需 boot-args：

```
-btlfxboardid -btlfxallowanyaddr
```

---

## 5. USB

| 组件 | 本机版本 | 下载 |
|---|---|---|
| **USBToolBox.kext** | 1.2.0 | https://github.com/USBToolBox/kext/releases/download/1.2.0/USBToolBox-1.2.0-RELEASE.zip |
| UTBDefault.kext | 1.0 | 由 USBToolBox 工具生成（本机为默认映射） |
| USBToolBox 工具 | — | https://github.com/USBToolBox/tool/releases |
| XHCI-unsupported.kext | 0.9.2 | https://github.com/RehabMan/OS-X-USB-Inject-All |
| XHCIProbe.kext | 1.0.0（自制） | 无下载，见 [USB 文档](07-usb.md) |

---

## 6. 工具（可选）

| 工具 | 用途 | 下载 |
|---|---|---|
| ProperTree | 图形化编辑 `config.plist` | https://github.com/corpnewt/ProperTree |
| Hackintool | 查看 PCI / USB / 显示设备 | https://github.com/headkaze/Hackintool |
| GenSMBIOS | 生成 SMBIOS 四件套 | https://github.com/corpnewt/GenSMBIOS |
| displayplacer | 命令行切分辨率 | https://github.com/jakehilborn/displayplacer/releases |
| BetterDisplay **v4.3.7** | 手动切 HiDPI | https://github.com/waydabber/BetterDisplay/releases |
| switchaudio-osx | 命令行切音频输出 | https://github.com/deweller/switchaudio-osx |

> ⚠️ **BetterDisplay 不要用 v5.x**：v5.2.1 编译目标为 macOS 26.3，在 15.x 上会报
> `Library not loaded: /usr/lib/swift/libswift_DarwinFoundation1.dylib`。

---

## 7. 镜像与网络

GitHub 直连不稳定时，在完整 URL 前加镜像前缀：

```bash
# 单文件
curl -L -o out.zip "https://gh-proxy.org/https://github.com/OWNER/REPO/releases/download/TAG/FILE"

# git clone
git clone https://gh-proxy.org/https://github.com/OWNER/REPO.git

# raw 文件
curl -sL "https://gh-proxy.org/https://raw.githubusercontent.com/OWNER/REPO/main/PATH"
```

实测可用前缀（本机网络，2026-10）：

| 前缀 | 状态 |
|---|---|
| `https://gh-proxy.org/` | ✅ 首选 |
| `https://gh-proxy.com/` | ✅ 备选 |
| `https://gh-proxy.net/` | ⚠️ 可用但慢 |

下载大文件前先探测：

```bash
curl -sL -r 0-1048575 -o /dev/null -w "%{http_code} %{speed_download}\n" "<镜像>/<url>"
```

HTTP 206 + 速度正常再全量下载；中断用 `curl -C -` 续传。

---

## 8. 一键下载脚本

在能联网的机器上执行，全部走镜像：

```bash
#!/bin/bash
set -e
M="https://gh-proxy.org/"
get() { curl -L --retry 3 -C - -O "${M}$1"; }

get https://github.com/acidanthera/OpenCorePkg/releases/download/1.0.8/OpenCore-1.0.8-RELEASE.zip
get https://github.com/dortania/build-repo/releases/download/Lilu-0515f40/Lilu-1.7.3-RELEASE.zip
get https://github.com/dortania/build-repo/releases/download/RestrictEvents-9265e78/RestrictEvents-1.1.7-RELEASE.zip
get https://github.com/dortania/OpenCore-Legacy-Patcher/raw/main/payloads/Kexts/Acidanthera/AMFIPass-v1.4.1-RELEASE.zip
get https://github.com/USBToolBox/kext/releases/download/1.2.0/USBToolBox-1.2.0-RELEASE.zip
get https://github.com/b00t0x/CpuTopologyRebuild/releases/download/2.0.2/CpuTopologyRebuild-2.0.2-RELEASE.zip
get https://github.com/souissiak1-maker/AirportRTW/releases/download/V2.2.1/AirportRTW-Sequoia-Release.zip
get https://github.com/thegwchr/RealtekBluetoothFirmware/releases/download/v1.0.2/RealtekBluetoothFirmware_v1.0.2_5080405E-068B-3F14-92D7-0F48AB51C52B.zip
get https://github.com/Mieze/RTL812xLucy/releases/download/v1.1.1/RTL812xLucy-V1.1.1.zip
get https://github.com/acidanthera/BrcmPatchRAM/releases/download/2.7.2/BrcmPatchRAM-2.7.2-RELEASE.zip
```

AppleALC / WhateverGreen / VirtualSMC / NVMeFix 用各自仓库的 `releases/latest` 即可。

---

## 9. 验证下载完整性

```bash
# 每个 kext 的可执行文件哈希
shasum -a 256 Kexts/*.kext/Contents/MacOS/*

# NullMoth 包内自带校验
shasum -a 256 -c SHA256SUMS
```

本机实测的关键哈希（用于核对版本是否被替换）：

| kext | 版本 | SHA-256（Contents/MacOS/*） |
|---|---|---|
| Lilu | 1.7.3 | `6bc64e6d9e1b4dd1f7c6477365d0b7f14734aa00be76321205e1e7a105d4340b` |
| VirtualSMC | 1.3.9 | `bf91e9542b86c20acaf210353a93742291c49328e2d14b03fa0fa4fc52b3b5ce` |
| AppleALC | 1.9.9 | `21d5ffbf515aba5f9cacf48c0d4bd0b11189cb844133f696f027fd5d7998e9dd` |
| CpuTopologyRebuild | 2.0.2 | `0e36496ff627db53002ad04bd8e1e910909e083e587609fb9b472d5f2d7bde07` |
| AirportRTW | 2.2.1 | `5a8b15bffca206d5533692b67a2337842586d9412617c4aad13dff567b4f3822` |
| RTL812xLucy | 1.1.100 | `ad6ca1836e07d9f689ffd1904d26fe7646c8a7075076005d26e7d58ef79435d5` |
| RealtekBluetoothFirmware | 1.0.2 | `eec4d77b529be6e24306fce5112c9cae63dc8f296ad8d527fec27323e142c2f9` |
| BlueToolFixup | 2.7.3 | `0395b1f46fa784ef8dd8aacd0a261da15bbc223c629e988ed738ddc129df7228` |
| NMHDA | 1.0.0 | `56afe28a283a5dcf19c8ca917b93119435d9ded3254f75a6757d94851cdc6140` |
| NVRM | 2.6.4 | `cea6fb0e6a63d02d58c008144c474a95e2c9b9e10941557652002f2e45a32d33` |
| NVAccel | 2.6.4 | `2926f8aa446a1b22df1c3527c06161de71ced022e91cf181281d33fa132617ee` |
| NVRMFB | 2.6.4 | `83390f173cdff995a9e9073e23572362b5b4dba6aca5892ed4873723605bce4e` |
| NVRMAGDC | 2.6.4 | `c90a08aff583708210df392be3ac21a1682126304b40b5afa43958077eb5619f` |
