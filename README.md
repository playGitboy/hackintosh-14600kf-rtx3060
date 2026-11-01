# 黑苹果实录：i5-14600KF + RTX 3060

> macOS 15.8.2 (24H232) · SMBIOS `MacPro7,1` · OpenCore 1.0.9 DBG · NullMoth 2.6.4
> 最后实测：**2026-11-01**

苹果官方从未支持 14 代 Raptor Lake 搭配 NVIDIA 独显。这台机器走的是 **1401 + NullMoth** 路线，结果是可用的：图形界面、Metal 加速、HiDPI、板载声卡、HDMI 音频、2.5G 有线、Wi-Fi 与蓝牙都能工作。

本仓库不是教程搬运，而是这台机器的**施工笔记**：装了什么、改了什么、为什么这么改、坏了怎么修。硬件接近的人可以照着抄；已经装完但卡在某个硬件上的人，可以直接跳到对应章节查。

---

## 这台机器

| 部件 | 型号 / 规格 | 关键 ID |
|---|---|---|
| CPU | Intel Core i5-14600KF（6 P-core + 8 E-core / 20 线程） | — |
| 主板 | 技嘉B760M GAMING XAX | PCH xHCI `8086:7a60` |
| 内存 | DDR4-3600 16 GB × 2 = 32 GB | — |
| 显卡 | NVIDIA GeForce RTX 3060 12 GB（GA106） | `10DE:2504` |
| 系统盘 | 单条 1 TB NVMe，GPT 多分区 | APFS 容器 363 GB |
| 有线网卡 | Realtek RTL8125B 2.5GbE | `10EC:8125` |
| 无线 / 蓝牙 | Realtek RTL8852BE（蓝牙走 USB） | `10EC:C852` / `0BDA:0852` |
| 声卡 | Realtek ALC897 + NVIDIA HDMI Audio | `10EC:0897` |

---

## 当前状态（2026-11-01 实测）

| 项目 | 状态 | 方案 | 备注 |
|---|---|---|---|
| 图形界面 / Metal | ✅ | NullMoth 2.6.4 | Metal 3，VRAM 12 GB，BAR1 8 GB |
| HiDPI | ✅ | NullMoth `nvfbhidpi=1` + 显示 override | 当前 1920×1080 HiDPI（帧缓冲 3840×2160） |
| 板载音频 ALC897 | ✅ | AppleALC 1.9.9，`layout-id=11` | 输出 / 输入 / 数字输出都在 |
| HDMI 音频 | ✅ | `NMHDA.kext` 1.0.0 | 当前默认输出就是 HDMI |
| 有线网络 | ✅ | RTL812xLucy 1.1.100 | `en0`，2500Base-T |
| Wi-Fi | ⚠️ 可用，默认关闭 | AirportRTW 2.2.1 | 与蓝牙共用天线，见 [网络与蓝牙](docs/06-network-bluetooth.md) |
| 蓝牙 | ✅（蓝牙+WIFI只能开其中一个） | RealtekBluetoothFirmware + BlueToolFixup | A2DP 耳机可用 |
| USB | ✅ | USBToolBox + UTBDefault + XHCIProbe | 默认端口映射，未做定制 |
| CPU 拓扑 | ✅ 20 线程 | CpuTopologyRebuild 2.0.2 + `ctrsmt=full` | `hw.physicalcpu=6` 是预期值 |
| 图形启动菜单 | ✅ | OpenCanopy + 主题资源 | 鼠标可用，10 秒超时 |
| 睡眠 | ⚠️ 已主动关闭 | `pmset sleep 0` | 台机策略，未验证真睡眠 |
| AirDrop / 接力 | ❌ | 非 Apple 网卡 | RTL8852BE 不支持 |

---

## 五步复现

> 每一步的验收命令都在对应文档里。**没看到验收输出，不算这一步过了。**

### 1. BIOS（本机实际设置）

```
Secure Boot              Disabled     ← 关，否则未签名 kext 被拒
Above 4G Decoding        Enabled      ← NullMoth 要大 BAR
Re-Size BAR Support      Enabled      ← 必须，否则 8 GB BAR 拿不到
XHCI Hand-off            Disabled     ← 交给 macOS XHCI 驱动接管
VT-d / IOMMU             Disabled     ← 配合 DisableIoMapper=true
CSM / Legacy Boot        Disabled
Fast Boot                Disabled
```

> 改 BIOS 一次只改一项，改完进系统验证。`XHCI Hand-off` 容易被漏掉，它影响进系统后 USB 是否稳定。

### 2. 1401 生成 EFI + 装系统

见 [安装流程](docs/02-install-1401.md)。核心：Windows 侧用 1401 扫硬件 → 生成 OpenCore EFI → 写安装盘 → 装 macOS。

### 3. 装显卡驱动

见 [显卡 NullMoth](docs/03-gpu-nullmoth.md)。`1401.app` 或 `tar.gz + install.sh`，装完必须重启两次（第一次允许扩展，第二次生效）。

### 4. 写 boot-args

本机实测可用串（完整解释见 [OpenCore 配置](docs/09-opencore-config.md)）：

```
debug=0x100 keepsyms=1 ctrsmt=full nvfb=1 nvaccel=1 nvfbheads=1
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0
gfxrst=4 nvfbhidpi=1 -btlfxboardid -btlfxallowanyaddr -alcdbg
```

### 5. 逐项修硬件

按顺序：显示 → 音频 → 网络 → USB → 电源。每修一项重启一次，别批量改。

---

## 文档导航

| 文档 | 内容 |
|---|---|
| [01 硬件与兼容性](docs/01-hardware.md) | 哪些硬件能驱动、哪些永远不行、风险分级 |
| [02 安装流程（1401）](docs/02-install-1401.md) | EFI 生成、安装盘、首次启动、装完的检查 |
| [03 显卡 NullMoth](docs/03-gpu-nullmoth.md) | 安装、验收四层、回滚三层、已知问题 |
| [04 HiDPI](docs/04-hidpi.md) | 三个必要条件、override 写法、切分辨率、回滚 |
| [05 音频](docs/05-audio.md) | ALC897 layout 注入、HDMI 音频、验证 |
| [06 网络与蓝牙](docs/06-network-bluetooth.md) | 2.5G 有线、RTL8852BE、Wi-Fi/蓝牙共存冲突与修复顺序 |
| [07 USB](docs/07-usb.md) | XHCI 匹配、USBToolBox、端口映射 |
| [08 CPU 与电源](docs/08-cpu-power.md) | 20 线程怎么来的、CpuTopologyRebuild、电源策略 |
| [09 OpenCore 配置](docs/09-opencore-config.md) | 本机 config.plist 实测值逐项解释 |
| [10 故障速查](docs/10-troubleshooting.md) | 按症状查：黑屏、无声、卡代码、菜单消失 |
| [11 驱动下载清单](docs/11-driver-links.md) | 全部 kext / 工具 / 镜像链接与版本 |
| [12 上游 issue 提炼](docs/12-upstream-issues.md) | 从 1401 / 驱动仓库 issue 学到的修复与验证方法 |
| [scripts/status.sh](scripts/status.sh) | 只读体检脚本，一次打印全部关键状态 |

---

## 三条规矩

1. **改 `config.plist` 前先备份，并把被改键的旧值写下来。** 没有旧值 = 不许改。
2. **一次只动一个变量。** 两次重启之间只改一个键或一个 BIOS 项，改完立刻验证。
3. **拿到 `kmutil` / `system_profiler` / `ioreg` 的输出才算修好。** 「好像能用了」不算。

---

## 已知限制（诚实清单）

- **Wi-Fi 与蓝牙抢天线**：RTL8852BE 的 Wi-Fi 驱动不做 BT 共存协调，2.4 GHz 下蓝牙 A2DP 会被饿死。本机默认开机关 Wi-Fi，走有线网络才能正常使用蓝牙。
- **无 AirDrop / Handoff / 通用剪贴板**：非 Apple 网卡，无解。
- **NVIDIA 驱动是第三方、非开源、非商用许可**（PolyForm Noncommercial），且厂商对 Ampere 只标 `Pending`——本机实测可用，但换卡必须自己验证。
- **睡眠未验证**：本机直接 `sleep 0` 关掉了。想让机器睡眠的人要自己测，并准备回滚。
- **蓝牙漏扫**：比如无法识别小米蓝牙遥控器pro
- **程序兼容性**：豆包语音输入法卡死；trae新版本不支持intel mac
- **Chrome 的 WebGL / DRM 视频**：不同版本驱动表现不一致，Safari 更稳。本机未系统测试。

---

## 免责与许可

- 这是**个人实机记录**，不是官方支持方案。照做导致的数据丢失、硬件损坏、系统无法启动，自行承担。
- 文档：[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh)
- 脚本：MIT
- **NullMoth 驱动为 PolyForm Noncommercial 1.0.0，禁止商用。** 本仓库不包含其二进制，只给官方获取方式。
- Apple、NVIDIA、Realtek 等商标归各自所有者。本仓库与上述公司无关。
