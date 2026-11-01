# 10 故障速查

> 按症状查。每条给出：怎么判断、为什么、怎么修、怎么回滚。
> 标 `[本机]` 的是这台机器上实际发生并解决的；标 `[社区]` 的是常见但本机没复现的。

---

## A. 启动阶段

### A1. 内核交接后零输出，卡在 OpenCore 菜单

| | |
|---|---|
| 判断 | 选了 macOS 之后屏幕不动，没有任何内核日志 |
| 原因 | `debug=0x100` 把错误静默进调试器；或 NVRAM 里的旧 `boot-args` 盖住了 config 里的新值 |
| 修 | 去掉 `debug=0x100`；确认 `NVRAM → Delete` 里有 `boot-args` |
| 回滚 | 加回 `debug=0x100` |

日志里出现 `OCVAR: Setting NVRAM ... boot-args - ignored, exists` 就是第二种情况。修好后应看到 `Deleting NVRAM ... boot-args - Success`。

### A2. 卡在 `EB|LOG:EXITBS:START` `[社区]`

| | |
|---|---|
| 原因 | VT-d 没关 / 混合核拓扑 / `DevirtualiseMmio` 方向错 |
| 修 | BIOS 关 VT-d；`DevirtualiseMmio=true`；`ProvideCurrentCpuInfo=true` |
| 验证 | 日志里不再出现 `OCA: Deleting table DMAR` |

### A3. 过了 EXITBS，但冻在 `[AHCI][HBA] start:` `[社区]`

| | |
|---|---|
| 原因 | **不一定是 SATA 不兼容**。新平台常见是时钟（TSC）非单调导致的早期冻死，AHCI 只是最后刷屏的一行 |
| 修 | 加非单调时钟补丁；或先 `cpus=1` 启动，确认是多核问题还是别的问题 |
| 注意 | 本机没踩到这条，因为用的是 NVMe；SATA 用户遇到时先别换主板 |

### A4. OpenCore 菜单只有 `Reset NVRAM`

| | |
|---|---|
| 原因 | `ScanPolicy` 位掩码算错，把 APFS/USB 都过滤了 |
| 修 | 先改 `0`（全放行），确认能看见所有系统盘，再收窄到 `17760515` |
| 教训 | `0x01070003` 这种「想隐藏 Windows」的值会连 APFS 位一起丢掉 |

### A5. 每次重启都进 Windows `[本机-多系统]`

| | |
|---|---|
| 原因 | Windows 快速启动/休眠跳过固件启动项；或 U 盘启动项 GUID 失效 |
| 修 | Windows 里 `powercfg /h off`，关 `HiberbootEnabled`；或 `bcdedit` 调整 `{fwbootmgr}` 顺序 |
| 验证 | U 盘根目录出现新的 `opencore-*.txt`，说明真的走了 OC |

### A6. 双系统时间差 8 小时 `[本机-多系统]`

| | |
|---|---|
| 原因 | macOS 把 RTC 当 UTC 写，Windows 按本地时间读 |
| 修 | Windows 注册表 `RealTimeIsUniversal=1`，然后 `w32tm /resync` |

---

## B. 显卡与显示

### B1. 装完驱动黑屏，但机器还活着

| | |
|---|---|
| 判断 | 能 ping 通、能 SSH/屏幕共享，就是没画面 |
| 原因 | 显示路径没起来；固件帧缓冲占了显示 index 0；或 zero-copy 路径不稳 |
| 修（按顺序） | ① boot-args 加 `-nvrmnoflip` ② 加 `-nvrmnogo` 隔离 ③ OC 菜单选 `1401: Start once without NVIDIA driver` ④ `Remove NVIDIA driver` |
| 回滚 | 删掉临时 boot-arg，或走卸载脚本 |

### B2. 桌面约 1 分钟后黑屏只剩鼠标

| | |
|---|---|
| 原因 | zero-copy 扫描输出路径问题（旧版本驱动） |
| 修 | `-nvrmnoflip` 强制走 copy 路径；升级到 2.6.x |

### B3. `system_profiler` 里没有 GeForce

| | |
|---|---|
| 判断 | `kmutil showloaded \| grep nullmoth` 也没有四行 |
| 原因 | kext 没进 Auxiliary KC |
| 修 | 重跑 install.sh；检查文件属主是 `root:wheel`；看 `kmutil inspect` 结果 |
| 验证 | 四个 kext + Metal 3 + 桌面稳定，三条都要 |

### B4. 有 Metal，但动画卡顿

| | |
|---|---|
| 原因 | 可能仍在走软件合成，或 `nvaccel` 没生效 |
| 检查 | `ioreg -l \| grep -i NVAccel`；看 WindowServer 日志 |
| 修 | 确认 `nvaccel=1`；确认没有残留的 `nv_disable=1` |

### B5. HiDPI 重启后掉回 1x

| | |
|---|---|
| 原因 | override 里缺 `IODisplayEDID`，系统重新读 EDID 重建模式表 |
| 修 | 补 EDID；检查 override 是否被系统更新覆盖 |
| 验证 | `system_profiler` 里 `Resolution` 是 `UI Looks like` 的 2 倍 |

### B6. 切分辨率后黑屏

| | |
|---|---|
| 处理 | 等 15 秒，系统通常自动回退；不回来就强制重启，删掉 override |
| 预防 | 只加面板能接受的时序；改完先用「系统设置 → 显示器」验证 |

---

## C. 音频

### C1. 板载声卡完全没设备

| | |
|---|---|
| 原因 | `layout-id` 写成了 integer，或 AppleALC 没加载 |
| 修 | 改成 `<data> 0b000000`；确认 `kmutil showloaded \| grep AppleALC` |
| 验证 | `SPAudioDataType` 出现 `Built-in Output` |

### C2. 有设备但没声音

| | |
|---|---|
| 修 | 换 layout（11 / 12 / 98 / 66 / 97）；boot-args 加 `alcid=NN` 临时覆盖；检查输出设备与音量 |

### C3. HDMI 没声音

| | |
|---|---|
| 原因 | `NMHDA.kext` 没加载，或驱动版本低于 2.6 |
| 检查 | `kmutil showloaded \| grep NMHDA`；`SPAudioDataType` 里有没有 `HDMI` |
| 修 | 确认 `EFI/OC/Kexts/NMHDA.kext` 存在且启用；升级驱动 |

---

## D. 网络与蓝牙

### D1. Wi-Fi 接口不出现

| | |
|---|---|
| 原因 | AirportRTW 版本与 macOS 不匹配（最常见）；或 kext 没加载 |
| 修 | macOS 15 用 `AirportRTW-Sequoia-Release.zip`；确认 `kmutil showloaded \| grep AirportRTW` |
| 验证 | `networksetup -listallhardwareports` 里有 Wi-Fi / en1 |

### D2. 蓝牙突然假死（PAGE_TIMEOUT）

| | |
|---|---|
| 判断 | `BT_ERROR_HCI_PAGE_TIMEOUT`；USB 里设备还在；热重启无效 |
| 根因 | Wi-Fi 与蓝牙抢天线，AirportRTW 不做 BT 共存协调 |
| 修（按顺序） | ① 关 Wi-Fi（**本机实测立刻恢复**）② `sudo pkill bluetoothd` ③ 关/开蓝牙 ④ 完全关机断电 30 秒 ⑤ 重插网卡/查天线 ⑥ 换卡 |
| 预防 | 用蓝牙音频时关 Wi-Fi；Wi-Fi 固定 5 GHz；装开机自动关 Wi-Fi 的 daemon |

### D3. 蓝牙能连但没声音

| | |
|---|---|
| 检查 | 输出设备是否选中蓝牙；A2DP 是否被 HFP 抢占（通话模式） |
| 修 | 声音设置里切输出；删配对重连 |

---

## E. USB

### E1. 某些 USB 端口不工作

| | |
|---|---|
| 原因 | 端口映射错误（`UTBMap` / `UTBDefault`） |
| 修 | 先禁用自定义映射，回退 `UTBDefault`；确认原生 XHCI 驱动加载 |
| 注意 | 映射做错会让端口直接消失，改之前备份 EFI |

### E2. 蓝牙设备在 USB 里消失

| | |
|---|---|
| 判断 | `SPUSBDataType` 里找不到 `0BDA:0852` |
| 原因 | USB 层掉设备（供电/映射/复位） |
| 修 | 检查 `SSDT-USBX`、`SSDT-USB-Reset`；换端口；断电重插 |

---

## F. 图形启动菜单

### F1. 菜单变回纯文字

| | |
|---|---|
| 原因 | `PickerMode` 不是 `External`；或 `OpenCanopy.efi` 没启用；或 `Resources/` 是空的 |
| 修 | 三项逐一检查；`Resources` 必须有真实的 Font/Image/Label 文件 |
| 回退 | 改 `PickerMode=Builtin` 就是文字菜单，稳定可用 |

### F2. 菜单图标丢失

| | |
|---|---|
| 原因 | `Resources/` 被清空，或主题 `PickerVariant` 指向不存在的目录 |
| 修 | 从备份恢复 `Resources/`；或改回 `Default` |

### F3. 菜单太大/太小

| | |
|---|---|
| 修 | `UIScale`：`0` 自动 / `1` 小 / `2` 大；配合 `Resolution=Max` |

---

## G. 系统与服务

### G1. `task_for_pid: Operation not permitted` 刷屏

| | |
|---|---|
| 原因 | `csr-active-config` 缺 `CSR_ALLOW_TASK_FOR_PID (0x004)`，典型值是 `0x0A43` |
| 修 | 改 `FF0F0000`（`0x0FFF`）；同时确认 `AMFIPass.kext` 加载 |
| 注意 | 本机 `0x0A43` 没出现这个症状，所以没改。出现再改。 |

### G2. App 一开就崩 / 签名页错误

| | |
|---|---|
| 原因 | SIP 太严 + AMFI 没放行 |
| 修 | `csr-active-config=0x0FFF`；`AMFIPass.kext` 启用；`amfi_get_out_of_my_way=0x1 amfi=0x80` |

### G3. 系统更新后驱动失效 `[社区]`

| | |
|---|---|
| 原因 | 系统更新会重建 Auxiliary KC，第三方 kext 可能被移除 |
| 修 | 重跑驱动安装脚本；升级驱动到支持新系统的版本 |
| 预防 | 更新前备份 EFI 和 `/Library/Extensions` |

---

## H. 排障通用手法

```bash
# 1) 打开详细日志（临时）
#    boot-args 加 -v keepsyms=1，去掉 debug=0x100

# 2) 看 OpenCore 日志
#    U 盘/EFI 根目录的 opencore-*.txt

# 3) 看内核日志
log show --last 10m --predicate 'process == "kernel"' --style compact | tail -50

# 4) 看驱动加载
kmutil showloaded --list-only | grep -Ei 'nullmoth|lilu|virtualsmc'

# 5) 隔离显卡
#    boot-args 加 -nvrmnogo，看系统能否起来

# 6) 隔离多核
#    boot-args 加 cpus=1，看是否与拓扑有关
```

### 一次只改一个变量

这条比任何具体命令都重要。同时改三个键，出问题后你无法归因，只能全部回退重来。
