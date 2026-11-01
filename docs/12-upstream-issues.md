# 12 上游 issue 提炼

> 来源：[nullmoth/1401](https://github.com/nullmoth/1401/issues) 与 [nullmoth/nvidia-macos-driver](https://github.com/nullmoth/nvidia-macos-driver/issues)
> 整理时间：2026-11-01。只收录对**这台机器**（14600KF / RTX 3060 / macOS 15.8.2 / 2.6.4）有判断价值的内容。

## 已应用到本机

### 1. `debug.nvrmfb_flip_latch=2` —— 每帧省约 14 ms

来源：[nvidia-macos-driver#300](https://github.com/nullmoth/nvidia-macos-driver/issues/300)

**背景**：默认 `flip_latch=1` 时，每次 present 都要等 flip 真正落到面板才返回。60 Hz 一帧只有 16.7 ms，这个等待把预算吃光。

**厂商在 2.5.2 提供 opt-in**：

```bash
sudo sysctl debug.nvrmfb_flip_latch=2
```

改为在**下一次 submit** 时检查，不再阻塞当前 present。

**本机实测**（2026-11-01）：

| 指标 | 默认 =1 | =2 |
|---|---|---|
| 平均 submit | **14 ms** | **< 1 ms** |
| `flip_latch_late` | 0 | 0 |
| `flip_latch_timeouts` | 0 | 0 |

测量方法：

```bash
s1=$(sysctl -n debug.nvrmfb_flip_us_sum); n1=$(sysctl -n debug.nvrmfb_flip_n)
sleep 10
s2=$(sysctl -n debug.nvrmfb_flip_us_sum); n2=$(sysctl -n debug.nvrmfb_flip_n)
echo "avg submit $(( (s2-s1)/(n2-n1)/1000 )) ms"
```

**持久化**：sysctl 重启后恢复默认。本仓库提供 LaunchDaemon：

```bash
sudo ./scripts/install-nvrmfb-latch.sh
# 卸载
sudo ./scripts/uninstall-nvrmfb-latch.sh
```

**风险**：厂商默认用 `1` 是为了压某些机器上的闪烁。若出现闪烁/撕裂，卸载脚本即可回退。

---

### 2. `nvfbheads=1` + 去掉 `-nvkmsnosmooth`

来源：[nvidia-macos-driver#283](https://github.com/nullmoth/nvidia-macos-driver/issues/283)（closed，[FIXED BUG]）

原文结论：

> Animation and window-transition stutter was caused by the OpenCore boot arguments. The EFI had `nvfbheads=4` and `-nvkmsnosmooth`. I changed this to `nvfbheads=1` and removed `-nvkmsnosmooth`. After rebooting, animations and window transitions are smooth again.

在 RTX 2070（Turing）上验证，作者认为可能适用于其他 Turing 卡。

**本机原来的值正好是** `nvfbheads=4 -nvkmsnosmooth`，已按此修改（2026-11-01）：

```
- nvfbheads=4 -nvkmsnosmooth
+ nvfbheads=1
```

单屏机器用 `1` 没有副作用；多屏再考虑 2/4。

> 这条与 flip_latch 是**两个独立变量**。如果改完出现问题，先回退 boot-args（`config.plist.bak-20261101-095941`），再单独测 flip_latch。

---

## 已解决、但本机不需要动

| issue | 症状 | 上游结论 | 本机 |
|---|---|---|---|
| [#30](https://github.com/nullmoth/1401/issues/30) | 安装到 19 分钟冻死，HID 全掉 | `UEFI → Quirks → ReleaseUsbOwnership=true` + `Booter → Quirks → DisableVariableWrite=true` | 已装好；`ReleaseUsbOwnership` 已是 true，`DisableVariableWrite` 保持 false |
| [#58](https://github.com/nullmoth/1401/issues/58) | Arrow Lake 启动卡 EXITBS / 拓扑 panic / storage 服务循环 | ① BIOS 关 VT-d（先关 X2APIC 解锁）② `ProvideCurrentCpuInfo=true` ③ `SetApfsTrimTimeout=0` 解决 `storagekitd` 重启循环 | ①② 已满足；③ 本机 `-1` 但无循环，不动 |
| [#69](https://github.com/nullmoth/1401/issues/69) | macOS 15/26 启动 non-monotonic time panic | 加 `CpuTscSync.kext` 1.1.2 | 本机无此 panic，不加 |
| [#97](https://github.com/nullmoth/1401/issues/97) | Ampere 笔记本卡 EXITBS | 最终修复未单列；对比中 `ResizeAppleGpuBars=-1`、`DisableIoMapper` 差异被记录 | 本机 `0` 可用，不动 |
| [#121](https://github.com/nullmoth/1401/issues/121) | USB 键鼠输入延迟、按键重复 | **2.6.4 已修** | 本机 2.6.4，无此问题 |
| [#26](https://github.com/nullmoth/1401/issues/26) / [#108](https://github.com/nullmoth/1401/issues/108) | EXITBS 卡死 | 关 VT-d；部分机器需关 HT / E 核；`ForceExitBootServices` + `SetupVirtualMap` | 本机 20 线程全开可启动，不关 |
| [#53](https://github.com/nullmoth/1401/issues/53) | Alder Lake-HX 卡 EXITBS | 关 VT-d + 关 HT + 1401 默认 EFI | 同上 |
| [#23](https://github.com/nullmoth/1401/issues/23) | 16 GB Ada 卡装驱动后卡 `PCI configuration begin` | BAR1 过大；`npci=0x2000` 能过 PCI 但引发 `AppleKeyStore` 循环 | 本机 12 GB / BAR1 8 GB，无此问题 |
| [#194](https://github.com/nullmoth/nvidia-macos-driver/issues/194) | RTX 3060 Ti 8 GB BAR1 黑屏只剩光标 | `nvAllocVram` 全落在 console range，WindowServer 分配被拒 | 1.15 时代问题，本机 2.6.4 正常 |

---

## 未解决，但有缓解手段

### 窗口/动画卡顿

相关：#196、#300、#352、#356、#397、#462。核心原因是每帧等待与合成路径的 CPU 开销。

已做的两件事（flip_latch、nvfbheads）针对的就是这一类。仍有卡顿时，按顺序试：

1. 确认没有多屏/高刷：降刷新率或单屏测试。
2. 关掉 `debug=0x100`（大量日志本身有开销）。
3. 不要开「降低透明度」以外的视觉效果叠加。
4. 用 `sysctl debug.nvaccel_iop_flips` 量化，而不是凭感觉。

### RTX 3060 的 10-bit（`l10r`）问题

见 [nvidia-macos-driver#392](https://github.com/nullmoth/nvidia-macos-driver/issues/392)：WindowServer 把合成面切到 `l10r`（10-bit），NVRMFB 只声明 8-bit scanout，于是拒绝所有帧，最后黑屏只剩光标。

**本机没有复现**（`log show` 无 `not BGRA`）。如果以后出现登录后黑屏、光标可动：

```bash
log show --last 5m --predicate 'eventMessage CONTAINS "not BGRA"' --style compact
```

命中就说明踩到了同一条路径，临时缓解是 `nvaccel=0`（牺牲加速），并去 issue 里补充自己的报告 ID。

### Chrome / WebGL

#406、#419、#426：NVMTL 的 SPIR-V 翻译器对某些 shader 结构（sampler 数组、bvec 比较等）支持不全，表现为 WebGL context lost 或白屏。

这不是配置问题，改 EFI 没用。规避：用 Safari；或等驱动更新。

### 蓝牙漏扫（小米遥控器 Pro 等 BLE 设备）

1401 与驱动仓库都没有针对这颗 Realtek 蓝牙的 BLE 配对修复。可尝试：

```bash
# 1. 确认 Wi-Fi 已关（共存问题优先排除）
networksetup -getairportpower en1

# 2. 重启蓝牙守护进程
sudo pkill bluetoothd

# 3. 让设备进入配对模式后重新扫描
#    系统设置 → 蓝牙，保持窗口打开 30 秒以上

# 4. 仍不行：完全关机断电 30 秒（复位固件），不是重启
```

BLE HID（遥控器、部分手柄）对 `BlueToolFixup` 的地址校验敏感，`-btlfxallowanyaddr` 必须保留。

---

## 一条方法论

上游 issue 里最有价值的不是「某个键改成什么」，而是**单变量对照**：

- #58 用四行矩阵证明了 `ProvideCurrentCpuInfo` 是唯一开关；
- #95 用逐项排除证明了 USB/GPU/kext 都不是冻结原因；
- #300 用 `debug.*` 计数器把「感觉卡」变成「14 ms/帧」。

照抄别人的整套 config 风险很高；照抄他们的**验证方法**才是可复用的。
