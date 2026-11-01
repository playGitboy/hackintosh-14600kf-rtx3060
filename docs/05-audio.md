# 05 音频

> 本机两套音频同时工作：板载 `ALC897`（ALC）和显卡 HDMI（NVIDIA + NMHDA）。
> 当前默认输出是 **HDMI**。

## 1. 板载声卡 ALC897

| 项 | 值 |
|---|---|
| 编解码器 | Realtek ALC897（`10EC:0897`） |
| kext | `AppleALC.kext` **1.9.9** |
| layout-id | **11** |
| 注入位置 | `DeviceProperties → Add → PciRoot(0x0)/Pci(0x1f,0x3)` |
| 注入键 | `layout-id` **和** `alc-layout-id` |

### 最容易踩的坑：必须是 data，不是 integer

```
正确：<0b000000>      ← 4 字节小端，值 11
错误：11              ← integer，AppleALC 直接忽略
```

`config.plist` 里两种写法在文本编辑器里看起来只差一点，效果是「有声」和「无声」。检查：

```bash
cd /Volumes/<EFI卷>/EFI/OC
grep -A2 "layout-id" config.plist
# 必须看到 <data> 而不是 <integer>
```

### 用 PlistBuddy 改（比手改安全）

```bash
CFG="/Volumes/NO NAME/EFI/OC/config.plist"
DEV="PciRoot(0x0)/Pci(0x1f,0x3)"

sudo /usr/libexec/PlistBuddy -c "Delete :DeviceProperties:Add:$DEV:layout-id" "$CFG" 2>/dev/null
sudo /usr/libexec/PlistBuddy -c "Add :DeviceProperties:Add:$DEV:layout-id data 0b000000" "$CFG"
sudo /usr/libexec/PlistBuddy -c "Delete :DeviceProperties:Add:$DEV:alc-layout-id" "$CFG" 2>/dev/null
sudo /usr/libexec/PlistBuddy -c "Add :DeviceProperties:Add:$DEV:alc-layout-id data 0b000000" "$CFG"
```

改完重启，不是注销。

### 验证

```bash
system_profiler SPAudioDataType | head -40
```

期望出现：

```
Built-in Output          Transport: Built-in   Output Source: Internal Speakers
Built-in Line Input      Transport: Built-in
Built-in Digital Output  Transport: Built-in   Output Source: Digital Out
```

### 没声音的排查顺序

1. **先看设备在不在。** `SPAudioDataType` 里连 `Built-in Output` 都没有 → layout 没生效，回到上面的 data 类型检查。
2. 设备在但没声 → 系统设置里选中 `Built-in Output`，检查音量不是 0，输出没被静音。
3. 换 layout：本机是 11，可试 `12`、`98`、`66`、`97`（AppleALC 对不同主板的内置配置）。改完重启。
4. 临时覆盖：boot-args 加 `alcid=12`（会盖过 `layout-id`），记得同步 `NVRAM → Delete`。
5. 还不行 → 看 `log show --last 5m --predicate 'process == "kernel"' | grep -i applealc`。

---

## 2. HDMI / DP 音频

| 项 | 值 |
|---|---|
| kext | `NMHDA.kext` 1.0.0（`com.nullmoth.NMHDA`） |
| 位置 | `EFI/OC/Kexts` |
| 依赖 | NullMoth 2.6.x 驱动本身 |

它把 NVIDIA 的 HDMI/DP 音频设备挂到 AppleHDA 上，系统里出现一个 `HDMI` 输出设备。

### 验证

```bash
system_profiler SPAudioDataType | grep -A4 "HDMI"
```

期望：

```
HDMI:
  Default Output Device: Yes
  Transport: HDMI
  Output Source: <你的显示器型号>
```

### 注意

- 这个是 **NullMoth 2.6.x 才有的能力**。更早的版本（1.14 时代）HDMI 音频是未解决的 open 问题。
- `NMHDA.kext` 放在 `EFI/OC/Kexts` 并由 OpenCore 注入，和 `/Library/Extensions` 里的 NVRM 系列不冲突。
- 如果加了 NMHDA 后开机卡住或音频设备异常，先禁用这个 kext 重启验证。

---

## 3. 两套音频同时存在时选谁

系统会同时列出内置输出和 HDMI。台机接显示器音箱时，HDMI 更方便；用耳机时选内置。

```bash
# 看当前默认输出
system_profiler SPAudioDataType | grep -B3 "Default Output Device: Yes"

# 切默认输出（需要知道设备名，也可在系统设置里点）
SwitchAudioSource -s "HDMI"      # 需要安装 switchaudio-osx
```

没有 `SwitchAudioSource` 就进「系统设置 → 声音 → 输出」手动选。

---

## 4. 本机实测状态

| 项目 | 状态 |
|---|---|
| ALC897 内置输出 | ✅ |
| ALC897 输入 / 线路输入 | ✅ |
| 数字输出 | ✅ |
| HDMI 音频 | ✅ 当前默认输出 |
| 蓝牙 A2DP | ✅ 见 [网络与蓝牙](06-network-bluetooth.md) |
| 开机提示音（OpenCore chime） | ❌ 未启用（`AudioSupport=false`） |

想在 OpenCore 阶段响一声，见 [OpenCore 配置](09-opencore-config.md) 的 `AudioSupport`。
