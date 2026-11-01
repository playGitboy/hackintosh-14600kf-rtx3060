# 03 显卡：NullMoth NVIDIA 驱动

> 本机：NullMoth **2.6.4**，RTX 3060 12 GB（GA106，`10DE:2504`），Metal 3 正常，BAR1 8 GB。

## 0. 它是什么

NullMoth 用 NVIDIA 自家的 r610 open kernel modules，在 macOS 上实现 Metal 显示与加速：

```
Metal App → NVMTLDriver.bundle → AIR→SPIR-V 翻译 → NVK（Mesa Vulkan + NAK）
          → NVRM / NVAccel / NVRMFB / NVRMAGDC → GPU
```

| 组件 | 位置 |
|---|---|
| Metal 插件 | `/Library/GPUBundles/NVMTLDriver.bundle` |
| NVK 后端 | `/Library/GPUBundles/nvmtl/` |
| 内核扩展 | `/Library/Extensions/NVRM.kext`、`NVAccel`、`NVRMFB`、`NVRMAGDC` |
| GSP 固件 | `/Library/NullMoth/nvfw/nvidia/` |
| 工具 / 卸载器 | `/Applications/1401.app` |

**关键设计**：kext 装在 `/Library/Extensions`，由 **Auxiliary Kernel Collection** 加载。**不要**再把同一批 kext 放进 `EFI/OC/Kexts` 注入一遍——会冲突。OpenCore 只负责 SIP、boot-args 和启动项。

许可：**PolyForm Noncommercial 1.0.0**。可以自用、研究、教学，**不能商用**。

---

## 1. 装前检查

少一条都可能白装：

```bash
# 1) BIOS 已开 Above 4G + Re-Size BAR（进系统后确认 BAR 大小）
ioreg -l | grep -i "bar1"

# 2) 当前 SIP 是否放行未签名 kext
csrutil status
nvram csr-active-config

# 3) 没有旧 NVIDIA 驱动残留
ls /Library/Extensions | grep -E 'NV|GeForce'
ls /Library/GPUBundles | grep -i nv

# 4) boot-args 里没有互相打架的参数
nvram boot-args
```

必须没有的东西：

| 项目 | 原因 |
|---|---|
| `nv_disable=1` | 会直接禁用 NVIDIA 驱动 |
| `agdpmod=pikera` | WhateverGreen 的 board-id 补丁，与本驱动抢显示路径 |
| `EFI/OC/Kexts` 里的 NVRM 系列 | 与 `/Library/Extensions` 重复注入 |
| NVIDIA 的 DeviceProperties | 本驱动不需要，填了反而干扰 |

---

## 2. 两条安装路线

### 路线 A：1401.app（本机用的）

```bash
hdiutil attach 1401-Mac-2.6.4.dmg
cp -R /Volumes/1401/1401.app /Applications/
open -a /Applications/1401.app
```

App 会：找到启动用的 OpenCore 分区 → 先备份 `config.plist.bak-<时间戳>` → 装驱动 → 在 OC 菜单加两项：

- `1401: Remove NVIDIA driver`（卸载并还原配置）
- `1401: Start once without NVIDIA driver`（只这一次不加载）

跑 app 时**必须插着启动盘**，因为它要改的就是那份 config。

### 路线 B：tar.gz + install.sh

```bash
tar -xzf nullmoth-nvidia-*.tar.gz && cd pkgroot
shasum -a 256 -c SHA256SUMS     # 每个文件都要 OK
sudo ./install.sh               # 拷文件 + 重建 Auxiliary KC
sudo shutdown -r now
```

`install.sh` 会做版本门禁、硬件确认、哈希校验，**先在临时目录试建 KC 并 `kmutil inspect` 验证**，通过后才替换正式集合。这是它比手工拷 kext 安全的地方。

首次加载后，macOS 可能要求在「系统设置 → 隐私与安全性」里允许扩展，允许后再重启一次。

---

## 3. 装完要确认的 OpenCore 配置

| 位置 | 本机值 | 作用 |
|---|---|---|
| `NVRAM → Add → boot-args` | 见下表 | 启用帧缓冲 / 加速 / HiDPI |
| `NVRAM → Delete → 7C436110-…` | 含 `boot-args`、`csr-active-config` | 不删旧的，`Add` 会被 `- ignored, exists` 吞掉 |
| `Booter → Quirks → ResizeAppleGpuBars` | `0`（本机） | 本机成功值；另一种做法是 `-1` 让 macOS 看完整 BAR |
| `UEFI → Quirks → ResizeGpuBars` | `-1` | BIOS 已开 ReBAR 时不要再让 OC 改 |
| `Kernel → Block → IONDRVSupport` | 本机**没有** Block | 驱动 README 建议 Block；本机未 Block 也能出图，两种都记录 |
| `Misc → Security → SecureBootModel` | `Disabled` | Apple Secure Boot 会拒绝未签名 kext |
| `csr-active-config` | `0x0A43`（本机） | 能跑；若出现服务成片报错，改 `0x0FFF` |

> **关于 csr**：本机 `0x0A43` 实测可用（桌面、Metal、音频都正常），但它缺 `CSR_ALLOW_TASK_FOR_PID (0x004)`。如果你遇到 `setuid/task_for_pid: Operation not permitted` 刷屏、App 一开就崩，改成 `FF0F0000`（`0x0FFF`）再试。
>
> **关于 ResizeAppleGpuBars / Block**：驱动 README 写的是 `-1` + Block IONDRVSupport，本机实际成功值是 `0` + 不 Block。说明这套组合不是唯一解，**一次只改一个，用验收输出判断**。

---

## 4. boot-args 逐项

本机实测串：

```
debug=0x100 keepsyms=1 ctrsmt=full nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0
gfxrst=4 nvfbhidpi=1 -btlfxboardid -btlfxallowanyaddr -alcdbg
```

| 参数 | 作用 | 备注 |
|---|---|---|
| `nvfb=1` | 启用 NVRMFB 帧缓冲 | 必需 |
| `nvaccel=1` | 启用 NVAccel（WindowServer 合成） | 必需 |
| `nvfbheads=4` | 显示头数量 | 本机单屏也用 4；出问题可试 `1` |
| `-nvkmsnosmooth` | 关闭 KMS 平滑过渡 | 减少黑屏闪烁 |
| `gfxrst=4` | 显卡复位策略 | 2.6.x 参数 |
| **`nvfbhidpi=1`** | **允许 NVRMFB 输出 HiDPI 模式** | HiDPI 的前提，详见 [HiDPI](04-hidpi.md) |
| `amfi_get_out_of_my_way=0x1` + `amfi=0x80` | 放开 AMFI，允许未签名 bundle / WindowServer 加载第三方 GPU bundle | 必需 |
| `ipc_control_port_options=0` | 放宽 IPC 控制端口 | 配合未签名进程 |
| `ctrsmt=full` | CpuTopologyRebuild：完整 SMT 拓扑 | 20 线程的关键 |
| `keepsyms=1` | 保留内核符号，panic 栈才有函数名 | 排障必需 |
| `debug=0x100` | 内核调试标志 | 本机常开；**排查启动问题时它会静默错误**，建议临时去掉 |
| `-btlfxboardid` / `-btlfxallowanyaddr` | BlueToolFixup 的蓝牙修复 | 见 [网络与蓝牙](06-network-bluetooth.md) |
| `-alcdbg` | AppleALC 调试日志 | 可选 |

排障专用（平时不加）：

| 参数 | 用途 |
|---|---|
| `-nvrmnoflip` | 强制走 copy 路径，治「桌面约 1 分钟后黑屏只剩鼠标」 |
| `-nvrmnogo` | 驱动待命不启动 GPU，用于隔离显示问题 |
| `-nvrmnobootscreen` | 不截取启动画面快照 |
| `nvrmsettle=10000` | Turing 等卡固件启动慢，给 10 秒 |
| `-nmlogooff` | 关掉驱动启动 logo |
| `nv_disable=1` | 完全禁用驱动（最轻的回退） |

---

## 5. 四层验收

缺一层都不算装好。

```bash
# ① 四个 kext 真的加载了
kmutil showloaded --list-only | grep -i nullmoth
# 期望：NVRM / NVAccel / NVRMFB / NVRMAGDC 四行

# ② 系统认了卡和 Metal
system_profiler SPDisplaysDataType | head -20
# 期望：GeForce RTX 3060，Metal Support: Metal 3

# ③ BAR 拿到了 8 GB
ioreg -l | grep -i "bar1"
# 期望：接近 8589934592（8 GiB）的值

# ④ 桌面稳定
#   · 连续显示 > 2 分钟不黑
#   · 拖动窗口、移动光标不闪
#   · 切一次分辨率再切回来，画面还在
log show --last 5m --predicate 'eventMessage CONTAINS "WindowServer"' --style compact | tail -20
```

本机 2026-11-01 实测：①②③ 全部通过，④ 连续使用稳定。

---

## 6. 已知问题

| 现象 | 状态 | 处理 |
|---|---|---|
| 桌面约 1 分钟后黑屏只剩鼠标 | 旧版本问题，2.6.x 已改善 | 加 `-nvrmnoflip` |
| 显示器热插拔不重新枚举 | 未解决 | 拔插线缆让它重新扫描 |
| 双屏改刷新率后另一块屏空白 | 厂商已知问题 | 单屏无影响 |
| 部分 DRM 视频 / Chrome WebGL 异常 | 与版本相关 | 用 Safari；或等驱动更新 |
| 睡眠唤醒后黑屏 | 未验证 | 本机直接关闭睡眠 |
| HDMI/DP 音频 | 2.6.x 通过 `NMHDA.kext` 解决 | 见 [音频](05-audio.md) |

---

## 7. 回滚三层

| 层 | 操作 | 影响 |
|---|---|---|
| L1 参数级 | boot-args 加 `-nvrmnoflip` 或 `-nvrmnogo` | 只改参数，不动文件 |
| L2 菜单级 | OC 菜单选 `1401: Start once without NVIDIA driver`（只这一次）或 `Remove NVIDIA driver`（下次启动自动卸干净并还原配置） | 需要 1401 装过一次 |
| L3 彻底卸载 | `sudo bash /Applications/1401.app/Contents/Resources/nullmoth-uninstall.sh`，再恢复 `config.plist.bak-*` | 删 kext、GPU bundle、`/Library/NullMoth`，重建 KC |

卸载后必须重启，不是注销。
