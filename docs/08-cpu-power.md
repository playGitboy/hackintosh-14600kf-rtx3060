# 08 CPU 与电源

> 本机 i5-14600KF：6 P-core + 8 E-core，**HT 和 E 核全开，20 线程可用**。

## 1. 14 代在 macOS 里的拓扑问题

macOS 的 CPU 调度假设 Intel 核心是同构的。14 代的 P-core 有超线程、E-core 没有，直接暴露给内核会得到错误的拓扑：

- 线程数与物理核数对不上
- 调度器把任务分给错误的核
- 某些情况下启动阶段就卡死

社区两种解法：

| 做法 | 代价 | 本机 |
|---|---|---|
| 关 HT + 关 E 核，只留 6C/6T | 损失约 70% 多线程性能 | ❌ 没采用 |
| `CpuTopologyRebuild` + HT 补丁 | 需要正确配对版本与 patch | ✅ 采用 |

## 2. 本机方案

### 必需项

| 项 | 值 | 作用 |
|---|---|---|
| `Kernel → Quirks → ProvideCurrentCpuInfo` | `true` | 让内核拿到真实核心布局与时序信息 |
| `CpuTopologyRebuild.kext` | 2.0.2 | 把 P/E 核重排成 macOS 能理解的非对称拓扑 |
| boot-arg | `ctrsmt=full` | 保留完整 SMT（20 线程） |
| `Kernel → Patch` | 3 条 HT 补丁 | 让 macOS 认 HT |

三条补丁的 `Comment` 原文：

```
force HT enabled for Sequoia or later
force HT enabled for Mojave to Sonoma
force HT enabled for High Sierra or earlier (untested)
```

`Count` 都是 `1`，按内核版本区间自动命中。它们来自 CpuTopologyRebuild 的配套说明，缺了会表现为「只有 14 线程」或「HT 逻辑核不可用」。

### 为什么 `hw.physicalcpu` 显示 6

`CpuTopologyRebuild` 把 6P+8E 重排成一个「Xeon 风格」的拓扑：

```
hw.ncpu        = 20    ← 总逻辑线程
hw.physicalcpu = 6     ← 伪装成 6 个物理核
hw.logicalcpu  = 20
```

这是**预期行为**，不是识别错误。系统信息里显示「Total Number of Cores: 6」也正常。

验证：

```bash
sysctl -n hw.ncpu hw.physicalcpu hw.logicalcpu
sysctl -n machdep.cpu.brand_string
```

### 查看实际负载分布

```bash
# 每个逻辑核的使用率
top -l 1 -n 0 | head -20

# 或图形化：活动监视器 → 窗口 → CPU 历史
```

跑一个多线程编译/转码，确认 20 个线程都有负载。如果只有 6 个在动，说明 HT 补丁没生效。

---

## 3. ACPI 与电源管理

| 文件 | 作用 |
|---|---|
| `SSDT-PLUG-ALT.aml` | 注入 `plugin-type=1`，让 XCPM 接管电源管理 |
| `SSDT-EC.aml` | 伪造 EC 设备（笔记本必需，台机用于满足 AppleACPI 期望） |
| `SSDT-SBUS.aml` | SBUS 设备 |
| `SSDT-RTCAWAC.aml` | 处理 AWAC/RTC 互斥，防 CMOS 重置 |

传感器：

```bash
kmutil showloaded --list-only | grep -E "SMCProcessor|SMCSuperIO"
```

装了 `SMCProcessor`（CPU 温度/电压）和 `SMCSuperIO`（风扇/主板传感器）后，iStat Menus 之类的工具才能读到数据。

---

## 4. 电源策略（本机）

台机策略：不休眠、只关屏。

```bash
sudo pmset -a sleep 0
sudo pmset -a displaysleep 10
sudo pmset -a hibernatemode 0
sudo pmset -a powernap 0
sudo pmset -a autopoweroff 0
sudo rm -f /var/vm/sleepimage
```

当前值：

```bash
pmset -g custom
```

预期看到 `sleep 0`、`hibernatemode 0`、`powernap 0`。

### 为什么不启用睡眠

- 本机没有验证过 S3 睡眠/唤醒在 NullMoth 驱动下是否正常。
- 睡眠唤醒黑屏是这类第三方 GPU 驱动的常见问题，排查成本高。
- 台机长期插电，不休眠的代价可以接受。

想试睡眠的人：先备份 EFI，改 `sleep 1` 测试，准备用 `-nvrmnogo` 或 OC 菜单回滚。

---

## 5. 性能调优（可选，全部可逆）

无驱动时期留下的调优，装好显卡后**大部分可以撤销**，因为 GPU 已经接管合成：

| 项目 | 命令 | 建议 |
|---|---|---|
| 降低透明度 | `defaults write ... reduceTransparency -bool true` | 装好显卡后可以关掉，恢复毛玻璃 |
| 降低动效 | `reduceMotion -bool true` | 同上 |
| 关 Spotlight | `mdutil -a -i off` | 需要搜索就开回来 |
| 关 Finder 动画 | `DisableAllAnimations` | 可选 |

回滚：

```bash
sudo defaults delete /Library/Preferences/com.apple.universalaccess reduceTransparency
sudo defaults delete /Library/Preferences/com.apple.universalaccess reduceMotion
sudo mdutil -a -i on
killall cfprefsd
```

> 这些设置是「没显卡驱动、纯软件渲染」阶段的续命手段。驱动正常后，关掉它们体验更好。

---

## 6. 验收

```bash
# 拓扑
sysctl -n hw.ncpu hw.physicalcpu hw.logicalcpu

# 电源管理是否由 XCPM 接管
ioreg -l | grep -i "plugin-type"
# 期望看到 plugin-type = 1

# 传感器
kmutil showloaded --list-only | grep -E "SMCProcessor|SMCSuperIO"

# 电源策略
pmset -g custom | head -15
```

20 线程全部可用、`plugin-type=1`、两个传感器 kext 加载，这三项过了就算正常。
