# 01 硬件与兼容性

> 先判定，再动手。判定错了，后面每一步都是白费。

## 1. 这台机器的判定结果

| 判定项 | 本机 | 结论 |
|---|---|---|
| CPU 是否混合核心 | 是（6P + 8E） | 需要 `ProvideCurrentCpuInfo` + HT 补丁 |
| GPU 在不在 NullMoth 设备表 | 在（Ampere / GA106） | 可走驱动路线，但厂商只标 `Pending`，必须实机验证 |
| 系统盘 | NVMe | 走原生 `AppleNVMe`，风险最低 |
| 系统数量 | 三系统（macOS + Windows + Linux） | 需要处理启动顺序与快慢启动 |
| 网络 | Realtek 有线 + Realtek 无线 | 都有第三方 kext，但无线能力受限 |

**档位**：混合核心 + NVMe + 未自动化验证的 NVIDIA 卡 = **能跑，但每个硬件都要自己验收**。

---

## 2. CPU

| 代际 | 代表 | 能不能跑 | 关键点 |
|---|---|---|---|
| 6–10 代 | i5-9400 / i7-10700 | ✅ 最稳 | 官方指南覆盖到此 |
| 12–14 代（混合核） | i5-12400 / i5-14600KF | ✅ 可跑 | `ProvideCurrentCpuInfo=true`；P/E 核拓扑要处理 |
| Core Ultra 200S（Arrow Lake） | Ultra 5 245K | ⚠️ 能跑但更麻烦 | 常需关 HT / 关 E 核、加时钟补丁 |
| AMD Ryzen | — | ⚠️ 另一条路线 | 本仓库不覆盖 |

14 代（Raptor Lake）和 12 代同属混合核，处理方式一致。本机的做法是 **不关 HT、不关 E 核**，靠 `CpuTopologyRebuild` + 三条 HT 补丁保留 20 线程，详见 [CPU 与电源](08-cpu-power.md)。

> 网上很多 14 代教程会教你关掉 HT 和 E 核「求稳」。那是牺牲一半性能换启动成功率。本机证明：配对正确的 kext 和补丁后，20 线程可以全开。

---

## 3. GPU

### 能驱动的范围

NullMoth（`nullmoth/nvidia-macos-driver`）基于 NVIDIA r610 open kernel modules，覆盖 **Turing 及以后**：

| 家族 | 型号 | 厂商验证状态 | 本机判断 |
|---|---|---|---|
| Turing | GTX 1650/1660、RTX 20 系 | `Pending` | 可试；可能需要 `nvrmsettle=10000` |
| **Ampere** | **RTX 30 系（含本机 RTX 3060）** | `Pending` | **本机实测出图 + Metal 3** |
| Ada | RTX 40 系 | `Pending` | 可试 |
| Blackwell | RTX 50 系 | RTX 5060 自动化验证 | 相对最有把握 |
| Pascal 及更早 | GTX 10 系及以前 | 不支持 | 只能基础显示，无加速 |

**设备表命中 ≠ 能出图。** 厂商的 `Pending` 只表示没做自动化验证，不代表不能用；反过来，在表里也不代表你这块卡一定能出图。唯一标准是实机验收。

### 不能驱动的

- Intel 核显（含本机这种 KF 无核显的情况）：不要加 `AAPL,ig-platform-id`，让它在固件层当 GOP 用即可。
- AMD RX 7000/9000、Intel Arc：macOS 无加速驱动。
- 笔记本 Optimus 内屏：如果屏幕走核显 mux，独显驱动也点不亮内屏。

---

## 4. 存储

| 类型 | 结论 |
|---|---|
| NVMe（M.2） | ✅ 首选，原生 `AppleNVMe`，不需要额外 kext |
| SATA AHCI | ✅ 能用，但新 PCH 上排障要先怀疑时钟/补丁，而不是 SATA 本身 |
| Intel RST / RAID | ❌ macOS 看不到盘，BIOS 必须切 AHCI |
| USB 安装盘 | 需要 `HfsPlus.efi`，且 `ScanPolicy` 不能过滤 USB |

本机是单条 NVMe，Windows / macOS / Linux 共存。装 macOS 前用**序列号**确认目标分区，不要认盘符或容量。

---

## 5. 网络与音频

| 设备 | 驱动 | 能力 |
|---|---|---|
| RTL8125B 2.5G | `RTL812xLucy.kext` | ✅ 完整，2.5G 全双工 |
| RTL8852BE Wi-Fi | `AirportRTW.kext` | ⚠️ 能上网，无 AirDrop/接力，与蓝牙抢天线 |
| RTL8852BE 蓝牙（USB） | `RealtekBluetoothFirmware` + `BlueToolFixup` | ✅ A2DP 可用，偶发假死 |
| ALC897 | `AppleALC` + `layout-id=11` | ✅ 输出/输入/数字输出 |
| NVIDIA HDMI 音频 | `NMHDA.kext` | ✅ 需要 NullMoth 2.6.x |

---

## 6. 装机前核实命令

macOS 侧（已装好系统时）：

```bash
system_profiler SPHardwareDataType | head -20
system_profiler SPDisplaysDataType | head -30
ioreg -l | grep -i '"model"' | head -10
kmutil showloaded --list-only | grep -Ei 'lilu|virtualsmc|nvrm|nvaccel'
```

Windows 侧（准备装 macOS 时）：

```powershell
Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors
Get-CimInstance Win32_VideoController | Select-Object Name,PNPDeviceID
Get-CimInstance Win32_DiskDrive | Select-Object Index,Model,SerialNumber,InterfaceType,Size
```

`PNPDeviceID` 里的 `SUBSYS` 是反序：`SUBSYS_25041462` 读作厂商 `1462` / 设备 `2504`。按正序查会永远对不上。

---

## 7. 什么时候该放弃

- 只有核显，且没有独显：能进系统，但没有图形加速，日常不可用。
- 笔记本内屏走 Optimus，且没有外接屏：内屏永远黑。
- 主板只有 Intel RST 且 BIOS 拿不到 AHCI：不要装。
- 期望「开箱即用、不用维护」：不要装。这套东西每次系统更新都可能要重新修。
