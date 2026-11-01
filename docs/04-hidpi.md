# 04 HiDPI 显示

> 本机面板原生 2560×1440，当前跑 **1920×1080 HiDPI**（帧缓冲 3840×2160）。
> 不需要 BetterDisplay 常驻。

## 1. 为什么非原生分辨率会糊

macOS 在 1x 模式下只有一种缩放方式：把逻辑分辨率直接铺到面板像素上。2560×1440 面板显示 1920×1080 时，每个逻辑像素对应 1.33 个物理像素，只能做粗糙插值，文字边缘必糊。

HiDPI 的做法是**反向**的：

```
逻辑 1920×1080  →  系统按 2 倍渲染成 3840×2160  →  GPU 缩回面板的 2560×1440 时序输出
```

多渲染 4 倍像素，再高质量下采样。代价是 GPU 负载，收益是文字锐利。

---

## 2. 三个必要条件（缺一不可）

| # | 条件 | 本机位置 |
|---|---|---|
| 1 | `nvfbhidpi=1` boot-arg | `NVRAM → boot-args` |
| 2 | 显示 override 文件，且**包含面板 EDID** | `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-6b3/DisplayProductID-27a9` |
| 3 | WindowServer 允许的帧缓冲上限 ≥ 目标 2x 分辨率 | `/Library/Preferences/com.apple.windowserver.plist` 的 `LimitsWidth / LimitsHeight` |

第 1 条让 NullMoth 的帧缓冲支持 HiDPI 模式；第 2 条告诉系统「这块面板支持哪些 2x 模式」；第 3 条防止 WindowServer 把 3840×2160 拒掉。

### 为什么 override 里必须有 EDID

只写 `scale-resolutions` 不写 `IODisplayEDID`，重启后系统会重新从显示器读 EDID、重建模式表，HiDPI 选项消失，退回 1x。

**EDID 是这个配置能活过重启的原因。**

---

## 3. override 文件怎么写

### 路径规则

```
/Library/Displays/Contents/Resources/Overrides/
└── DisplayVendorID-<vendor 十六进制>/
    └── DisplayProductID-<product 十六进制>
```

本机面板：vendor `0x06b3`（1715）、product `0x27a9`（10153），所以是 `DisplayVendorID-6b3/DisplayProductID-27a9`。

读自己的值：

```bash
system_profiler SPDisplaysDataType | grep -iE "Resolution|Display Serial"
ioreg -lw0 | grep -i "IODisplayEDID" | head -3
```

`IODisplayEDID` 后面那串十六进制就是完整 EDID（本机 256 字节）。

### 结构

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DisplayProductID</key>
    <integer>10153</integer>
    <key>DisplayProductName</key>
    <string>AUS VZ27A</string>
    <key>DisplayVendorID</key>
    <integer>1715</integer>
    <key>IODisplayEDID</key>
    <data>
    <!-- 你的面板 EDID，base64 -->
    </data>
    <key>scale-resolutions</key>
    <array>
        <!-- 5120×2880，16 字节 HiDPI 形式 -->
        <data>AAAUAAAAC0AAAAABACAAAA==</data>
        <!-- 3840×2160，16 字节 HiDPI 形式 -->
        <data>AAAPAAAACHAAAAABACAAAA==</data>
    </array>
</dict>
</plist>
```

### `scale-resolutions` 的字节格式

每条是 big-endian 的 `width, height`，然后可选地追加标志：

| 长度 | 结构 | 用途 |
|---|---|---|
| 8 字节 | `width(4) + height(4)` | 普通模式 |
| 12 字节 | `width + height + 0x00000001` | 带有效标志 |
| 16 字节 | `width + height + 0x00000001 + 0x00200000` | **HiDPI 模式** |

本机每个逻辑分辨率都写了 8 / 12 / 16 三种长度，共 10 组 × 3 = 30 条：

```
5120×2880   (2560×1440 @2x)
4608×2592   (2304×1296 @2x)
4096×2304   (2048×1152 @2x)
3840×2160   (1920×1080 @2x)   ← 当前使用
3600×2028   (1800×1014 @2x)
...
```

注意：这里写的是**物理像素**尺寸，不是「Looks like」的逻辑尺寸。

### 安装

```bash
D=/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-6b3
sudo mkdir -p "$D"
sudo cp DisplayProductID-27a9 "$D/"
sudo chown root:wheel "$D/DisplayProductID-27a9"
sudo chmod 644 "$D/DisplayProductID-27a9"
sudo plutil -lint "$D/DisplayProductID-27a9"   # 必须 OK
sudo reboot
```

---

## 4. 切换分辨率

override 生效后，系统设置里通常能直接选到 HiDPI 模式。如果看不到，用命令行工具强制切：

```bash
# 本机脚本（依赖 BetterDisplay 临时拉起，App 本身不常驻）
~/hidpi.sh            # 查看当前
~/hidpi.sh 1152       # 2048×1152 HiDPI
~/hidpi.sh 1080       # 1920×1080 HiDPI
~/hidpi.sh native     # 2560×1440 1x
```

也可以用 `displayplacer`：

```bash
displayplacer list
displayplacer "id:<id> res:1920x1080 scaling:on"
```

> `CGDisplayCopyAllDisplayModes` 里 HiDPI 模式数是 0（属于私有模式），所以纯系统 API 列不出来。要么用 override + 系统设置，要么用 BetterDisplay / displayplacer 这类工具。

---

## 5. 验证

```bash
system_profiler SPDisplaysDataType | grep -E "Resolution|UI Looks like|Framebuffer"
```

期望：

```
Resolution: 3840 x 2160
UI Looks like: 1920 x 1080 @ 59.00Hz
```

`Resolution` 是帧缓冲，`UI Looks like` 是逻辑分辨率。两者是 2 倍关系才算 HiDPI 生效。

再看时序：

```bash
ioreg -l | grep -E "IOFBCurrentPixelClock|IOFBCurrentPixelCount"
```

本机 1920×1080 HiDPI 时 `PixelClock = 241500000`（241.5 MHz），这是面板原生 2560×1440 的时序，说明是 GPU 缩放输出，不是面板改了分辨率。

---

## 6. 回滚

```bash
# 1) 删 override
sudo rm -rf /Library/Displays/Contents/Resources/Overrides/DisplayVendorID-6b3

# 2) 恢复 WindowServer 默认（可选）
sudo rm -f /Library/Preferences/com.apple.windowserver.plist

# 3) 重启
sudo reboot
```

只想临时回到 1x，可以在系统设置里选原生分辨率，不用删文件。

---

## 7. 常见坑

| 现象 | 原因 | 处理 |
|---|---|---|
| 重启后 HiDPI 掉回 1x | override 缺 `IODisplayEDID` | 补 EDID，检查文件是否被覆盖 |
| 系统设置里没有 HiDPI 选项 | `nvfbhidpi=1` 没生效，或 override 路径/ID 写错 | 核对 vendor/product 十六进制 |
| 选了 HiDPI 但画面超出屏幕 | `LimitsWidth/Height` 太小 | 改 windowserver 配置，或换更低一档 |
| 菜单文字巨大 / 太小 | 这是 OpenCore 的 `UIScale`，不是 HiDPI | 见 [OpenCore 配置](09-opencore-config.md) |
| 切完黑屏 | 模式不被面板接受 | 等 15 秒自动回退；或强制重启后删 override |
