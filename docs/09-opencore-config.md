# 09 OpenCore 配置速查

> 以下全部是**本机 `config.plist` 的实际值**（OpenCore 1.0.9 DBG，macOS 15.8.2）。
> 不是「推荐值」，是「这台机器跑得起来的值」。换硬件要重新判断。

## 1. ACPI

| 文件 | 启用 | 作用 |
|---|---|---|
| `SSDT-PLUG-ALT.aml` | ✅ | CPU 电源管理（XCPM） |
| `SSDT-EC.aml` | ✅ | 伪造 EC |
| `SSDT-SBUS.aml` | ✅ | SBUS 设备 |
| `SSDT-RTCAWAC.aml` | ✅ | RTC/AWAC 互斥，防 CMOS 重置 |
| `SSDT-USB-Reset.aml` | ✅ | USB 控制器复位 |
| `SSDT-USBX.aml` | ✅ | USB 供电 |
| `SSDT-Disable_Network_RP01.aml` | ❌ | 备用，未启用 |

`ACPI → Delete` 本机为空（没有删 DMAR）。VT-d 通过 BIOS + `DisableIoMapper` 处理。

---

## 2. Kernel → Add（19 个 kext，全部启用）

| # | kext | 版本 | 作用 |
|---|---|---|---|
| 1 | `Lilu.kext` | 1.7.3 | 补丁加载器（必需） |
| 2 | `AMFIPass.kext` | 1.4.1 | AMFI 开启时加载未签名 kext |
| 3 | `AppleALC.kext` | 1.9.9 | 板载声卡 |
| 4 | `CpuTopologyRebuild.kext` | 2.0.2 | P/E 核拓扑重建 |
| 5 | `NVMeFix.kext` | 1.1.4 | NVMe 电源管理 |
| 6 | `RTL812xLucy.kext` | 1.1.100 | 2.5G 有线 |
| 7 | `RestrictEvents.kext` | 1.1.7 | 屏蔽内存/CPU 提示 |
| 8 | `VirtualSMC.kext` | 1.3.9 | SMC 模拟（必需） |
| 9 | `SMCProcessor.kext` | 1.3.9 | CPU 传感器 |
| 10 | `SMCSuperIO.kext` | 1.3.9 | 风扇/主板传感器 |
| 11 | `USBToolBox.kext` | 1.2.0 | USB 映射框架 |
| 12 | `UTBDefault.kext` | 1.0 | 默认端口映射 |
| 13 | `WhateverGreen.kext` | 1.7.2 | 显卡通用补丁 |
| 14 | `XHCI-unsupported.kext` | 0.9.2 | 补全 XHCI 匹配 |
| 15 | `AirportRTW.kext` | 2.2.1 | RTL8852BE Wi-Fi |
| 16 | `BlueToolFixup.kext` | 2.7.3 | 蓝牙修复 |
| 17 | `RealtekBluetoothFirmware.kext` | 1.0.2 | 蓝牙固件 |
| 18 | `NMHDA.kext` | 1.0.0 | NVIDIA HDMI 音频 |
| 19 | `XHCIProbe.kext` | 1.0.0 | 自制，提高 XHCI 匹配优先级 |

> **NVRM / NVAccel / NVRMFB / NVRMAGDC 不在这份列表里。** 它们在 `/Library/Extensions`，由 Auxiliary Kernel Collection 加载。重复注入会打架。

### Kernel → Patch（3 条 HT 补丁）

```
force HT enabled for Sequoia or later
force HT enabled for Mojave to Sonoma
force HT enabled for High Sierra or earlier (untested)
```

`Enabled=true`、`Count=1`。详见 [CPU 与电源](08-cpu-power.md)。

### Kernel → Block

本机为空。驱动 README 建议 Block `com.apple.iokit.IONDRVSupport`，但本机没有 Block 也能出图。两种做法都记录，改之前备份。

### Kernel → Emulate

```
Cpuid1Data = 55 06 0A 00 00 00 00 00 ...   (Comet Lake 0x000A0655)
Cpuid1Mask = ff ff ff ff ff 00 00 00 ...
DummyPowerManagement = false
```

把 CPUID 伪装成 macOS 认识的最新型号。14 代不伪装会在内核极早期被拒绝。

---

## 3. Kernel → Quirks（只列 true 的）

| 键 | 值 | 作用 |
|---|---|---|
| `AppleXcpmCfgLock` | true | 绕过 CFG Lock，让 XCPM 可用 |
| `CustomSMBIOSGuid` | true | 配合 `PlatformInfo → UpdateSMBIOSMode=Custom` |
| `DisableIoMapper` | true | 不让内核用 IOMMU 映射（配合 BIOS 关 VT-d） |
| `DisableLinkeditJettison` | true | 防止 Lilu 依赖的 kext 被提前卸载 |
| `PanicNoKextDump` | true | panic 时不打印 kext 列表（减少日志噪音） |
| `PowerTimeoutKernelPanic` | true | 电源超时不要直接 panic |
| `ProvideCurrentCpuInfo` | true | 混合核必需 |

其余（`AppleCpuPmCfgLock`、`XhciPortLimit`、`LapicKernelPanic` 等）都是 false。

---

## 4. Booter → Quirks

| 键 | 值 |
|---|---|
| `AllowRelocationBlock` | true |
| `AvoidRuntimeDefrag` | true |
| `DevirtualiseMmio` | true |
| `EnableSafeModeSlide` | true |
| `EnableWriteUnprotector` | false |
| `FixupAppleEfiImages` | true |
| `ProtectUefiServices` | true |
| `ProvideCustomSlide` | true |
| `RebuildAppleMemoryMap` | true |
| `SetupVirtualMap` | true |
| `SyncRuntimePermissions` | true |
| **`ResizeAppleGpuBars`** | **0** |
| `ProvideMaxSlide` | 0 |

`ResizeAppleGpuBars` 的两种路线：

- `0`：macOS 只看到最小 BAR（本机用的）。
- `-1`：让 macOS 用固件给的真实 BAR（驱动 README 的写法）。

本机 `0` 能出图且 HiDPI 正常。改这个值必须重启验证，不要和 `ResizeGpuBars` 同时改。

---

## 5. UEFI

### Quirks（非默认项）

| 键 | 值 | 作用 |
|---|---|---|
| `ReleaseUsbOwnership` | true | 启动时从固件接管 USB |
| `RequestBootVarRouting` | true | 路由 boot-var 写操作 |
| `ResizeGpuBars` | -1 | BIOS 已开 ReBAR，不再让 OC 改 |

### Drivers

| 驱动 | 启用 | 作用 |
|---|---|---|
| `HfsPlus.efi` | ✅ | 读 HFS+ |
| `OpenRuntime.efi` | ✅ | OC 运行时（必需） |
| `ResetNvramEntry.efi` | ✅ | 菜单里的 Reset NVRAM |
| `OpenCanopy.efi` | ✅ | 图形化启动菜单 |

### Output（图形菜单）

| 键 | 值 | 说明 |
|---|---|---|
| `Resolution` | `Max` | 用显示器最大分辨率 |
| `UIScale` | `2` | 2 倍缩放 |
| `TextRenderer` | `BuiltinGraphics` | 图形文字渲染 |
| `ProvideConsoleGop` | `true` | OpenCanopy 必需 |
| `DirectGopRendering` | `false` | 兼容性优先 |
| `GopPassThrough` | `Disabled` | — |

> `UIScale=2` + `Resolution=Max` 在 2560×1440 上相当于 1280×720 的布局。觉得菜单太大就改 `UIScale=1`。

### Audio（开机提示音）

`AudioSupport=false`（当前没有开机声）。想开启：

```
AudioSupport = true
PlayChime    = Enabled
AudioDevice  = PciRoot(0x0)/Pci(0x1b,0x0)
```

---

## 6. NVRAM

### Add

```
7C436110-AB2A-4BBB-A880-FE41995C9F82
  boot-args          = （见下）
  csr-active-config  = 43 0A 00 00   (0x0A43)
```

### Delete

```
7C436110-AB2A-4BBB-A880-FE41995C9F82
  - ForceDisplayRotationInEFI
  - csr-active-config
  - bluetoothExternalDongleFailed
4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102
```

**`Delete` 里必须有同名键。** 不删旧的，`Add` 会被静默忽略（日志里是 `- ignored, exists`）。

### boot-args

```
debug=0x100 keepsyms=1 ctrsmt=full nvfb=1 nvaccel=1 nvfbheads=1
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0
gfxrst=4 nvfbhidpi=1 -btlfxboardid -btlfxallowanyaddr -alcdbg
```

> 2026-11-01 已按上游 #283 把 `nvfbheads` 改为 1 并移除 `-nvkmsnosmooth`，原因见 [上游 issue 提炼](12-upstream-issues.md)。

逐项解释见 [显卡 NullMoth](03-gpu-nullmoth.md#4-boot-args-逐项)。

### csr-active-config 位表

`0x0A43` 解开：

| 位 | 名称 | 状态 |
|---|---|---|
| 0 `0x001` | `UNTRUSTED_KEXTS` | ✅ |
| 1 `0x002` | `UNRESTRICTED_FS` | ✅ |
| 2 `0x004` | **`TASK_FOR_PID`** | ❌ **缺** |
| 3 `0x008` | `KERNEL_DEBUGGER` | ❌ |
| 4 `0x010` | `APPLE_INTERNAL` | ❌ |
| 5 `0x020` | `UNRESTRICTED_DTRACE` | ❌ |
| 6 `0x040` | `UNRESTRICTED_NVRAM` | ✅ |
| 7 `0x080` | `DEVICE_CONFIGURATION` | ❌ |
| 8 `0x100` | `ANY_RECOVERY_OS` | ❌ |
| 9 `0x200` | `UNAPPROVED_KEXTS` | ✅ |
| 10 `0x400` | `EXECUTABLE_POLICY_OVERRIDE` | ❌ |
| 11 `0x800` | `UNAUTHENTICATED_ROOT` | ✅ |

本机 `0x0A43` 实测能跑。如果出现：

- `setuid/task_for_pid: Operation not permitted` 刷屏
- App 一打开就崩
- 系统服务成片失败

改成 `FF0F0000`（`0x0FFF`，全开）。写入是 little-endian，所以 `0x0FFF` 写成 `FF 0F 00 00`。

---

## 7. Misc

### Boot

| 键 | 值 |
|---|---|
| `PickerMode` | `External` |
| `PickerAttributes` | `17`（`0x11`：卷图标 + 鼠标指针） |
| `PickerVariant` | `Default` |
| `ShowPicker` | true |
| `Timeout` | 10 |
| `HideAuxiliary` | false |
| `LauncherOption` | `Full` |
| `TakeoffDelay` | 0 |
| `HibernateMode` | `None` |

### Security

| 键 | 值 | 说明 |
|---|---|---|
| `ScanPolicy` | `0` | 全放行，调试期首选 |
| `SecureBootModel` | `Disabled` | 否则未签名 kext 全被拒 |
| `Vault` | `Optional` | 没做 vault 签名不能设 `Secure` |
| `DmgLoading` | `Signed` | — |
| `BlacklistAppleUpdate` | true | — |
| `ExposeSensitiveData` | 7 | — |

> `ScanPolicy=0` 会让菜单显示所有可启动项（包括 Windows 和 U 盘）。稳定后想隐藏，改成 `17760515`（`0x010F0103`，只认 APFS 系统盘）。**不要自己乱算位掩码**，算错会让菜单只剩 `Reset NVRAM`。

---

## 8. PlatformInfo

| 键 | 值 |
|---|---|
| `SystemProductName` | `MacPro7,1` |
| `ProcessorType` | `3841` |
| `SpoofVendor` | true |
| `SystemMemoryStatus` | `Auto` |
| `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` | 本机唯一值（已脱敏，不在仓库中） |

序列号决定 iCloud / iMessage / App Store，必须自己用 `macserial` 生成，**不要抄别人的**。四件套要成套，改一个就全换。

生成：

```bash
# GenSMBIOS 或 OpenCore 自带的 macserial
macserial -m MacPro7,1 -n 3 -g
```

---

## 9. DeviceProperties

```
PciRoot(0x0)/Pci(0x1f,0x3)
  layout-id     = 0b 00 00 00   (data, 值 11)
  alc-layout-id = 0b 00 00 00   (data, 值 11)
```

NVIDIA 显卡**不加任何 DeviceProperties**。

---

## 10. 改配置的安全流程

```bash
# 1) 挂载 EFI
sudo diskutil mount disk0s1

# 2) 备份（带时间戳）
CFG="/Volumes/NO NAME/EFI/OC/config.plist"
sudo cp -p "$CFG" "$CFG.bak-$(date +%Y%m%d-%H%M%S)"

# 3) 只改一个键
sudo /usr/libexec/PlistBuddy -c "Set :Booter:Quirks:ResizeAppleGpuBars -1" "$CFG"

# 4) 校验 plist 还能解析
plutil -lint "$CFG"

# 5) 卸载并重启
sudo diskutil unmount "/Volumes/NO NAME"
sudo reboot
```

改坏了：进 OpenCore 菜单，从 `config.plist.bak-*` 恢复；或者用备份的整份 EFI 覆盖。
