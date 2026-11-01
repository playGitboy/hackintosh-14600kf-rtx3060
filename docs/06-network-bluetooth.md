# 06 网络与蓝牙

> 本机三块网卡：Realtek 2.5G 有线、Realtek RTL8852BE 无线、同一张卡的蓝牙（USB 通道）。
> **日常走有线；Wi-Fi 默认关闭，因为它会干扰蓝牙。**

## 1. 有线：RTL8125B 2.5G

| 项 | 值 |
|---|---|
| 芯片 | Realtek RTL8125B（`10EC:8125`） |
| kext | `RTL812xLucy.kext` 1.1.100 |
| 接口 | `en0` |
| 状态 | 2500Base-T 全双工 |

装好即用，不需要额外配置。验证：

```bash
system_profiler SPNetworkDataType | grep -A8 "Ethernet"
ifconfig en0 | grep -E "status|media"
```

`media: autoselect (2500Base-T <full-duplex>)` 说明跑在 2.5G。

> `RealtekRTL8111.kext` 只覆盖 1G 卡，**不覆盖 8125**，别装错。

---

## 2. Wi-Fi：RTL8852BE

| 项 | 值 |
|---|---|
| 芯片 | Realtek RTL8852BE（`10EC:C852`） |
| kext | `AirportRTW.kext` **2.2.1**（`com.senmiko.AirportRTW`） |
| 接口 | `en1` |
| 协议 | 802.11 a/b/g/n/ac，2.4G + 5G |
| MinKernel | 21.0.0 |

### 版本必须按系统选

AirportRTW 的 release 按 macOS 版本分包：Monterey / Ventura / Sonoma 14.0 / Sonoma 14.4 / **Sequoia** / Tahoe。

本机 macOS 15.8.2 → 用 **`AirportRTW-Sequoia-Release.zip`**。下错版本的表现是「kext 加载了但接口不出现」。

### 能力边界

- ✅ 正常上网
- ❌ AirDrop / Handoff / 通用剪贴板 / 接力
- ❌ Apple Watch 解锁
- ⚠️ 与蓝牙共用天线，见第 4 节

验证：

```bash
networksetup -listallhardwareports | grep -A2 "Wi-Fi"
networksetup -getairportpower en1
system_profiler SPAirPortDataType | head -30
```

---

## 3. 蓝牙：RTL8852BE 的 USB 部分

| 项 | 值 |
|---|---|
| 芯片 | Realtek（与 Wi-Fi 同卡，走 USB） |
| kext 1 | `RealtekBluetoothFirmware.kext` 1.0.2（固件） |
| kext 2 | `BlueToolFixup.kext` 2.7.3（macOS 12+ 修复） |
| boot-args | `-btlfxboardid -btlfxallowanyaddr` |

**两个 boot-arg 缺一不可**：少了 `-btlfxboardid`，BlueToolFixup 不会改 board-id；少了 `-btlfxallowanyaddr`，地址校验过不去。

验证：

```bash
system_profiler SPBluetoothDataType | head -25
```

期望：`State: On`、`Transport: USB`、`Chipset: THIRD_PARTY_DONGLE`。

### 已知日志噪音

`bluetoothd` 会周期性搜索一个内置控制器（`bm3_usb`），日志里刷错误。不影响使用，不用管。

---

## 4. Wi-Fi 与蓝牙抢天线（本机最重要的坑）

### 现象

A2DP 耳机播放中突然断流，之后所有连接报 `BT_ERROR_HCI_PAGE_TIMEOUT`。热重启无效。

### 判断依据

| 观察 | 含义 |
|---|---|
| `openConnection` 返回 `0xe00002d6` | HCI 命令发不出去，超时 |
| 日志 `BT_ERROR_HCI_PAGE_TIMEOUT` | 控制器无法发起寻呼，TX 不工作 |
| USB 里设备还在（`0BDA:0852`） | 卡没掉，问题在固件/射频，不是硬件断连 |
| `pipe stalled` on Bluetooth endpoint 0x00 | **不能单独判死**：正常 HCI 响应也会 STALL |

### 根因

`AirportRTW` 不支持 `APPLE80211_IOC_BTCOEX_PROFILE`。日志实测：

```
res=FAIL:-536870201:0xe00002c7   (kIOReturnUnsupported)
```

也就是说，Wi-Fi 驱动**不做 Wi-Fi/蓝牙时分协调**。2.4 GHz 下 Wi-Fi 射频占满共享天线，蓝牙 A2DP 的发包被饿死，最终 PAGE_TIMEOUT，控制器进入假死。

### 处理顺序（别一上来就断电）

1. **先关 Wi-Fi**
   ```bash
   sudo networksetup -setairportpower en1 off
   ```
   本机实测：关掉后**立即恢复**，耳机自动重连，不用重启、不用断电。

2. 无效 → 重启蓝牙守护进程
   ```bash
   sudo pkill bluetoothd      # 会自动拉起
   ```

3. 仍无效 → 关蓝牙再开
   ```bash
   blueutil -p 0 && sleep 2 && blueutil -p 1
   ```
   没有 `blueutil` 就在系统设置里关/开一次。

4. 仍无效 → **完全关机**（不是「重新启动」），断电 30 秒再开。
   热重启不切断 M.2 卡供电，复位不了固件。S5 断电是最后手段。

5. 仍无效 → 重插 M.2 网卡、检查天线（Wi-Fi 与蓝牙**共用 MAIN 天线**）。

6. 仍无效 → 换卡。RTL8852BE 的蓝牙部分偶发崩溃是这颗芯片的已知问题。

### 降低复发

- 用蓝牙音频时关 Wi-Fi；要上网用有线。
- 必须开 Wi-Fi 时，把 Wi-Fi 固定到 **5 GHz**（2.4 GHz 与蓝牙重叠最严重）。
- 本机直接把「开机自动关 Wi-Fi」做成了 LaunchDaemon。

---

## 5. 开机自动关 Wi-Fi（本机已启用）

| 项 | 路径 |
|---|---|
| 辅助脚本 | `/usr/local/bin/bt-priority.sh` |
| LaunchDaemon | `/Library/LaunchDaemons/local.bt-priority.plist` |
| 日志 | `/var/log/bt-priority.log` |

检查：

```bash
launchctl print system/local.bt-priority | grep -E 'state|last exit'
networksetup -getairportpower en1     # 期望 Off
tail /var/log/bt-priority.log
```

手动触发一次：

```bash
sudo launchctl kickstart -k system/local.bt-priority
```

仓库里的脚本：

- [`scripts/bt-priority.sh`](../scripts/bt-priority.sh) — daemon 实际执行的动作
- [`scripts/install-bt-priority.sh`](../scripts/install-bt-priority.sh) — 安装
- [`scripts/uninstall-bt-priority.sh`](../scripts/uninstall-bt-priority.sh) — 卸载并恢复 Wi-Fi

---

## 6. 蓝牙体检（只读）

```bash
# 控制器状态
system_profiler SPBluetoothDataType | head -25

# 最近的蓝牙错误
log show --last 10m --predicate 'process == "bluetoothd"' --style compact | tail -30

# USB 上还在不在
system_profiler SPUSBDataType | grep -A6 -i bluetooth
```

仓库脚本 [`scripts/status.sh`](../scripts/status.sh) 会把这几项一起打印。
