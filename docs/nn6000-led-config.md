# Linksys NN6000 LED 配置分析与修复

> **适用固件**: ImmortalWRT SNAPSHOT (Kernel 6.12+) / OpenWrt Chaos Calmer 15.05.1
> **硬件平台**: Qualcomm IPQ6018/IPQ6000
> **最后更新**: 2026-07-18

---

## 1. 硬件 LED 概述

NN6000 前面板有 **3 色状态指示灯**（红/绿/蓝/黄混色）及 2 个 Wi-Fi 指示灯，由 GPIO 驱动。

### 1.1 GPIO 映射

| sysfs 名称 (ImmortalWRT) | sysfs 名称 (Chaos Calmer) | GPIO | 有效电平 | 物理颜色 |
|---|---|---|---|---|
| `red:status` | `led_red` | GPIO 50 | 低电平 | 🔴 **红** (ImmortalWRT 中实际为绿, 见下方说明) |
| `green:status` | `led_green` | GPIO 70 | 低电平 | 🟢 **绿** (ImmortalWRT 中实际为红) |
| `blue:status` | `led_blue` | GPIO 69 | 低电平 | 🔵 **蓝** (ImmortalWRT 中实际为黄) |
| — | `led_2g` | GPIO 37 | 高电平 | 2.4GHz Wi-Fi |
| — | `led_5g` | GPIO 35 | 高电平 | 5GHz Wi-Fi |
| `mmc0::` | `mmc0::` | — | — | eMMC 读写活动 |

> GPIO 控制器: `1000000.pinctrl` (80 个 GPIO 引脚)

### 1.2 DTS 默认状态

| LED | `default-state` | `linux,default-trigger` |
|---|---|---|
| GPIO 50 (red) | `on` | — |
| GPIO 70 (green) | `off` | — |
| GPIO 69 (blue) | `off` | — |
| GPIO 37 (2g) | `off` | `led_2g` (非标准) |
| GPIO 35 (5g) | `off` | `led_5g` (非标准) |

---

## 2. 软件架构

```
┌──────────────────────────────────────────────┐
│  上层应用                                     │
│  repacd (Linksys RE/AC 守护进程)              │
│  17 种 LEDState 模式管理红/绿双色 LED          │
│  配置文件: /etc/config/repacd                 │
├──────────────────────────────────────────────┤
│  中间层                                       │
│  /etc/init.d/led (OpenWrt 标准 LED 框架)      │
│  config_load system → config_foreach load_led │
├──────────────────────────────────────────────┤
│  底层                                         │
│  leds-gpio 内核模块 + Device Tree             │
│  /sys/class/leds/* sysfs 接口                 │
└──────────────────────────────────────────────┘
```

### 2.1 ImmortalWRT vs Chaos Calmer 差异

| 项目 | Chaos Calmer (4.4.60) | ImmortalWRT (6.12.71) |
|---|---|---|
| **LED 命名** | `led_red`, `led_green`, `led_blue` | `red:status`, `green:status`, `blue:status` |
| **亮度范围** | 0-255 (PWM) | 0/1 (二进制开关) |
| **WiFi LED** | 独立 `led_2g`/`led_5g` | 无独立 WiFi LED |
| **WiFi 触发器** | 不支持 | 支持 `phy0rx/phy0tx/phy0radio` |
| **DTS 默认** | `led_red` `default-state=on` | 三色均无默认触发器 |

### 2.2 repacd LEDState 状态机

`repacd` (Range Extender / AP Control Daemon) 管理 17 种状态模式，使用 `led_0`/`led_1` 抽象（硬编码映射到红/绿 LED）：

| LEDState 模式 | led_0 (红) | led_1 (绿) | 用户可见 |
|---|---|---|---|
| `Reset` | off | off | 全灭 |
| `NotAssociated` | timer 500/500ms | off | 红灯慢闪 |
| `AutoConfigInProgress` | timer 250/250ms | off | 红灯快闪 |
| `Measuring` | timer 250/250ms | timer 250/250ms | 红绿交替快闪 |
| `WPSTimeout` | timer 2000/1000ms | off | 红灯长闪 |
| `AssocTimeout` | timer 5000/1000ms | off | 红灯极长闪 |
| `RE_MoveCloser` | on | off | 红灯常亮 |
| `RE_MoveFarther` | off | on | 绿灯常亮 |
| `RE_LocationSuitable` | on | on | 琥珀色 |
| `RE_BackhaulGood` | on | on | 琥珀色 |
| `RE_BackhaulFair` | on | off | 红灯常亮 |
| `RE_BackhaulPoor` | off | on | 绿灯常亮 |
| `RE_SwitchingBSTA` | timer 250/250ms | off | 红灯快闪 |
| `InCAPMode` | on | on | 琥珀色 |
| `CL_*` | 各种组合 | 各种组合 | 客户端模式指示 |

---

## 3. 已知问题: ImmortalWRT DTS 标签反了

### 3.1 问题现象

通过逐灯测试确认，ImmortalWRT 固件中 DTS 标签与实际物理颜色不符：

```
sysfs 节点名      GPIO    写入后用户看到的颜色
───────────────────────────────────────────
red:status       GPIO 50  →  🟢 绿色
green:status     GPIO 70  →  🔴 红色
blue:status      GPIO 69  →  🟡 黄色
```

### 3.2 修复方案

已在构建系统中添加编译时自动修复 (`wrt_core/modules/target_fixes.sh` → `fix_nn6000_led_label()`)，使用 awk 脚本在构建过程中重命名 DTS 节点和标签：

| 编译前 | 编译后 | GPIO | 物理颜色 |
|---|---|---|---|
| `status-red { label = "red:status"; }` | → `status-green { label = "green:status"; }` | GPIO 50 | 🟢 绿 |
| `status-green { label = "green:status"; }` | → `status-red { label = "red:status"; }` | GPIO 70 | 🔴 红 |
| `status-blue { label = "blue:status"; }` | → `status-yellow { label = "yellow:status"; }` | GPIO 69 | 🟡 黄 |

修复后刷机，sysfs 名称将正确对应实际颜色。

---

## 4. 手动控制 LED

### 4.1 临时控制 (重启失效)

```bash
# ImmortalWRT
echo 1 > /sys/class/leds/red:status/brightness   # 开红灯
echo 0 > /sys/class/leds/red:status/brightness   # 关红灯

# Chaos Calmer
echo default-on > /sys/class/leds/led_red/trigger
echo 255 > /sys/class/leds/led_red/brightness    # 开红灯 (PWM)
echo none > /sys/class/leds/led_red/trigger
echo 0 > /sys/class/leds/led_red/brightness      # 关红灯
```

### 4.2 持久化配置

在 `/etc/config/system` 中添加:

```uci
config led 'led_red'
    option name 'Red LED'
    option sysfs 'red:status'        # ImmortalWRT
    option trigger 'default-on'
    option default '0'

config led 'led_green'
    option name 'Green LED'
    option sysfs 'green:status'
    option trigger 'default-on'
    option default '1'
```

### 4.3 利用 custom-boot 框架

设备支持 `/etc/custom-boot.d/` 开机自启脚本:

```bash
mkdir -p /etc/custom-boot.d/01-led-fix
cat > /etc/custom-boot.d/01-led-fix/apply.sh << 'EOF'
#!/bin/sh
# 绿灯常亮
echo 1 > /sys/class/leds/green:status/brightness
echo 0 > /sys/class/leds/red:status/brightness
EOF
chmod +x /etc/custom-boot.d/01-led-fix/apply.sh
```

---

## 5. 相关文件清单

| 文件 | 作用 |
|---|---|
| `/etc/modules.d/60-leds-gpio` | LED GPIO 内核模块 |
| `/etc/init.d/led` | OpenWrt LED 初始化脚本 |
| `/etc/config/system` | 系统配置 (可含 `config led`) |
| `/etc/config/repacd` | Linksys RE/AC 守护进程配置 (含 17 种 LEDState) |
| `/proc/device-tree/leds/` | 设备树 LED 节点 |
| `/sys/class/leds/*/` | sysfs LED 控制接口 |

---

## 6. 编译时 DTS 补丁参考

`target_fixes.sh` 中的 `fix_nn6000_led_label()` 使用 awk 直接在 DTS 源文件中交换 `status-red` 和 `status-green` 节点的全部内容（节点名、标签、GPIO 值），并将 `status-blue` 重命名为 `status-yellow`。

如需手动验证或修改，可在构建树中找到 DTS 文件后执行:

```bash
# DTS 文件路径 (示例)
# target/linux/qualcommax/files-6.18/arch/arm64/boot/dts/qcom/ipq6000-xxxx.dts
```