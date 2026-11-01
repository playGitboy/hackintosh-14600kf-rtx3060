# 02 安装流程（1401）

> 本机实际使用的工具：`1401.app` **2.6.4**（macOS 侧），EFI 由同一套工具生成后长期手工微调。
> 1401 是 NullMoth 配套的硬件扫描 + OpenCore EFI 生成 + 安装盘制作工具，不是苹果官方工具。

## 0. 先理解 1401 做什么

```
扫硬件（CPU / GPU / 网卡 / 声卡 / 磁盘）
      ↓
生成 OpenCore EFI（ACPI + kext + config.plist）
      ↓
写入 U 盘（macOS 安装盘）
      ↓
macOS 装完 → 1401 Mac app 装 NVIDIA 驱动、改 boot-args、加回滚菜单项
```

它解决的是「从零配出一份能启动的 EFI」，**不解决装完之后每个硬件的细调**。后者才是本仓库的主要内容。

## 1. 准备

| 需要 | 说明 |
|---|---|
| 一个 ≥ 16 GB U 盘 | 会被整盘抹掉 |
| Windows 或另一台 Mac | 用来跑 1401，写安装盘 |
| 有线网络 | macOS 安装器下载系统需要；Wi-Fi 在安装阶段通常不可用 |
| 目标盘 | 建议整块独立盘；本机是多系统共存，见第 6 节 |

下载来源见 [驱动清单](11-driver-links.md)。GitHub 直连不稳时用镜像前缀：

```bash
curl -L -o 1401-Mac.dmg \
  "https://gh-proxy.org/https://github.com/nullmoth/1401/releases/latest/download/1401-Mac-<ver>.dmg"
```

**版本必须用最新。** 老版本缺混合核心修复，也会把已知的显示问题原样带进来。

## 2. 生成 EFI

1. 运行 1401，先做硬件扫描（Check this PC）。
2. 选择 macOS 版本（本机装的是 15.x）。
3. 生成 EFI 到 U 盘的 ESP 分区。
4. 生成完，**先把整份 EFI 复制到另一块盘备份**，再开始装。

本机最终 EFI 的位置与结构：

```
EFI/
├── BOOT/BOOTx64.efi
└── OC/
    ├── config.plist          # 主配置
    ├── config.plist.bak-*    # 历史备份
    ├── OpenCore.efi          # 1.0.9 DBG
    ├── ACPI/                 # 7 个 SSDT
    ├── Drivers/              # HfsPlus / OpenRuntime / ResetNvramEntry / OpenCanopy
    ├── Kexts/                # 18 个 kext
    └── Resources/            # 图形菜单主题
```

## 3. BIOS

与当前 config 匹配的最小集合（本机实际设置）：

```
Secure Boot              Disabled     ← 关，否则未签名 kext 被拒
Above 4G Decoding        Enabled      ← NullMoth 要大 BAR
Re-Size BAR Support      Enabled      ← 必须，否则 8 GB BAR 拿不到
XHCI Hand-off            Disabled     ← 交给 macOS 的 XHCI 驱动接管
VT-d / IOMMU             Disabled     ← 配合 DisableIoMapper=true
CSM / Legacy Boot        Disabled
Fast Boot                Disabled
Hyper-Threading          Enabled      ← 本机没关，靠补丁解决
Active E-Cores           All          ← 本机没关
SATA Mode                AHCI
```

> `XHCI Hand-off = Disabled` 容易被忽略：它让固件不要把 USB 控制器「交接」给操作系统，从而由 macOS 的 `AppleUSBXHCISPT` 完整接管。开着它时，部分主板会出现 U 盘能启动、进系统后 USB 设备异常的情况。
>
> 关 HT / 关 E 核是很多 14 代教程的「保命」做法，但会砍掉一半性能。本机用 `CpuTopologyRebuild` + HT 补丁保留 20 线程，见 [CPU 与电源](08-cpu-power.md)。

## 4. 写盘与安装

1. 1401 会把 macOS 安装器写入 U 盘。
2. 重启，选 U 盘启动，进 OpenCore 菜单。
3. 选 macOS 安装器，先跑磁盘工具：目标盘抹成 **APFS / GUID**。
4. 安装。中途会重启数次，每次仍从 U 盘进 OpenCore，选安装器或新系统盘。
5. 首次进桌面后，**立刻把 U 盘 EFI 复制到硬盘 EFI**，否则拔盘就进不去系统。

安装阶段没有 NVIDIA 驱动，画面走固件的 GOP 帧缓冲。此时出现「分辨率不对、动画卡」是正常的，不要在这一步折腾显卡。

## 5. 装完的第一次体检

```bash
# 系统版本
sw_vers

# 有没有进到真正的系统盘
diskutil info / | grep -E "Volume Name|File System"

# OpenCore 配置有没有被正确读取
nvram boot-args

# 关键 kext 是否从 EFI 加载
kmutil showloaded --list-only | grep -Ei 'lilu|virtualsmc|whatevergreen|applealc'
```

验收标准：系统版本正确、`boot-args` 与 config 一致、Lilu / VirtualSMC / AppleALC 已加载。此时**还没有** NVIDIA 驱动，`system_profiler SPDisplaysDataType` 里看不到 Metal，是预期的。

## 6. 多系统注意事项

本机同一块 NVMe 上有 Windows、Linux（两个 EFI 分区）和 macOS。踩过的点：

| 问题 | 处理 |
|---|---|
| 每次重启都进 Windows | Windows 的「快速启动 / 休眠」会跳过固件启动项；`powercfg /h off`，并关 `HiberbootEnabled` |
| 时间差 8 小时 | Windows 写 `RealTimeIsUniversal=1`，或让 macOS 也用本地时间（不推荐） |
| OpenCore 菜单看不到系统盘 | `ScanPolicy` 算错，先设 `0` 全放行，确认能看见后再收窄 |
| 多个 EFI 分区分不清 | 按分区大小和内容认，不要按 disk 序号 |

## 7. 装完驱动之后

显卡驱动是**最后一步**，见 [显卡 NullMoth](03-gpu-nullmoth.md)。顺序很重要：

```
系统能进桌面 → 有线网络可用 → 备份 EFI → 装显卡驱动 → 显示/HiDPI → 音频 → 无线/蓝牙 → USB
```

显卡驱动装完如果黑屏，先别重装系统。OpenCore 菜单里如果有 `1401: Remove NVIDIA driver`，选它并按提示确认，它会卸掉驱动并恢复配置。
