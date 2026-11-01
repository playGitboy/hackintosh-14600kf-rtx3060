# 07 USB

> 本机 USB 走默认端口映射，没有做逐端口定制。日常使用（键鼠、U 盘、蓝牙）正常。

## 1. 控制器与驱动

| 项 | 值 |
|---|---|
| 控制器 | Intel Raptor Lake PCH xHCI（`8086:7a60`） |
| 系统驱动 | `AppleUSBXHCISPT` |
| 框架 | `USBToolBox.kext` 1.2.0 |
| 映射 | `UTBDefault.kext`（通用默认表） |
| 补匹配 | `XHCI-unsupported.kext` 0.9.2 |
| 提高优先级 | `XHCIProbe.kext` 1.0.0（自制） |
| ACPI | `SSDT-USB-Reset.aml`、`SSDT-USBX.aml` |

### 为什么需要 XHCIProbe

新 PCH 的 xHCI PCI ID 不在 `AppleUSBXHCISPT` 的匹配表里，系统可能不加载原生驱动，或加载顺序被别的驱动抢走。

自制一个只负责「匹配」的 kext，把 `IOPCIPrimaryMatch` 写成自己的控制器 ID，让原生驱动更早认领：

```xml
<key>IOKitPersonalities</key>
<dict>
  <key>XHCIProbe</key>
  <dict>
    <key>CFBundleIdentifier</key><string>com.sen.XHCIProbe</string>
    <key>IOClass</key><string>IOService</string>
    <key>IOMatchCategory</key><string>XHCIProbe</string>
    <key>IONameMatch</key><string>pci8086,7a60</string>
    <key>IOProviderClass</key><string>IOPCIDevice</string>
    <key>IOPCIPrimaryMatch</key><string>0x7a608086</string>
  </dict>
</dict>
```

它不实现任何驱动逻辑，只起「提前认领 + 触发匹配」的作用。换主板要改 `0x7a608086`。

> 本机这个 kext 是实验性补丁。如果你没有遇到 USB 控制器不被识别的问题，**不需要加它**，先用 `USBToolBox + UTBDefault` 裸跑。

## 2. SSDT 的作用

| 文件 | 作用 |
|---|---|
| `SSDT-USB-Reset.aml` | 启动时复位 USB 控制器，避免固件遗留状态 |
| `SSDT-USBX.aml` | 注入 USB 供电属性（大电流充电、外设供电） |

`USBX` 只影响供电声明，不改变端口映射。iPhone 充电慢、移动硬盘掉盘时可以检查它有没有加载。

## 3. 端口映射（可选）

默认映射（`UTBDefault`）能用，但有两个代价：

- 端口数量按通用表走，可能多出不存在或漏掉真实端口。
- 部分内部端口（蓝牙、摄像头）可能被错误分类。

要做定制映射：

1. 下载 **USBToolBox** 工具（macOS 版）。
2. 在 macOS 里运行，扫描当前所有端口。
3. **每个物理端口插一个设备**（USB 2 和 USB 3 分别插一遍），让工具记录。
4. 生成 `UTBMap.kext`，替换 `UTBDefault.kext`。
5. 重启，逐个端口验证。

验证端口：

```bash
ioreg -p IOUSB -l -w0 | grep -E "USB Product Name|PortNum|locationID" | head -40
```

> 没做映射也能用。**先让系统稳定，再考虑映射**——映射做错会导致某些端口直接消失，反而更难排查。

## 4. 蓝牙走 USB 的注意点

本机蓝牙是 RTL8852BE 的 USB 部分，在 `system_profiler SPUSBDataType` 里显示为：

```
Bluetooth USB Host ControlleX
  Vendor ID: 0x0bda (Realtek)
  Product ID: 0x0852
```

如果蓝牙突然消失，先看这里还在不在：

- **在** → 问题在固件/射频，按 [网络与蓝牙](06-network-bluetooth.md) 的处理顺序走。
- **不在** → USB 层掉设备，检查端口映射、供电、`SSDT-USB-Reset`。

## 5. 验证清单

```bash
# 控制器认到了吗
ioreg -l | grep -i "XHC" | head -5

# 驱动加载了吗
kmutil showloaded --list-only | grep -Ei "USBToolBox|UTBDefault|XHCIProbe"

# 设备树
system_profiler SPUSBDataType | head -60

# USB 供电属性
ioreg -l | grep -i "UsbPowerCharacteristics"
```

## 6. 常见坑

| 现象 | 原因 | 处理 |
|---|---|---|
| U 盘能启动但进系统后不认 | 端口映射错 / `XhciPortLimit` 相关 quirk | 先禁用 `UTBMap`，用 `UTBDefault` 验证 |
| 蓝牙时有时无 | USB 端口供电或映射不稳 | 检查端口、`SSDT-USBX` |
| 所有 USB 设备都慢 | 跑在 USB 2 通道 | 检查线材/端口，确认 USB3 端口映射正确 |
| 睡眠唤醒后 USB 失效 | 未验证 | 本机不睡眠，见 [CPU 与电源](08-cpu-power.md) |
