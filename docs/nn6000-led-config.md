# Link NN6000 LED 配置分析

> **硬件平台**: Qualcomm IPQ6018/IPQ6000
> **适用固件**: 原厂 Chaos Calmer 15.05.1 / ImmortalWRT SNAPSHOT
> **最后更新**: 2026-08-01
>
> **定制 LED 服务**: 本仓库实现了自定义 `/etc/init.d/led-ctrl` 5 状态 RGB LED 服务，
> 见 `wrt_core/patches/led-ctrl.init` 和 `wrt_core/patches/led-ctl`。
> 详见 [CHANGES.md](./CHANGES.md) 第 13 节。

---

## 1. 硬件 LED 概述

NN6000 前面板有一颗 **RGB 三色状态指示灯**（红/绿/蓝），通过混色可显示琥珀色。
另有 2 个 Wi-Fi 指示灯（2.4G/5G，位于机壳内部，外观不可见）和 1 个 eMMC 活动指示灯。

所有状态灯由 GPIO 通过 `leds-gpio` 内核模块驱动。

### 1.1 GPIO 映射表

以下映射经**两个固件分别逐灯实测交叉验证**确认：

| GPIO | sysfs (原厂) | sysfs (ImmortalWRT) | 硬件驱动方式 | **物理颜色** |
|---|---|---|---|---|
| 50 | `led_red` | `red:status` | 低电平有效 | 🔴 **红** |
| 70 | `led_green` | `green:status` | 低电平有效 | 🟢 **绿** |
| 69 | `led_blue` | `blue:status` | 低电平有效 | 🔵 **蓝** |
| 37 | `led_2g` | — | 高电平有效 | 2.4G Wi-Fi（壳内）|
| 35 | `led_5g` | — | 高电平有效 | 5G Wi-Fi（壳内）|
| — | `mmc0::` | `mmc0::` | — | eMMC 读写活动 |

> **验证方法（2026-07-18/19）：**
>
> 1. 原厂固件：先 kill 自动恢复进程 `wan_net_stat.sh`，然后用后台循环锁定单灯状态，
>    排除干扰后逐一点亮确认颜色。
> 2. ImmortalWRT：利用其极性配置错误的特性（`brightness` 值反相），
>    通过写入反相值确认每个 sysfs 节点对应的物理 LED。

### 1.2 DTS 默认状态

| sysfs 节点 | `default-state` | 说明 |
|---|---|---|
| `led_red` / `red:status` | `on` | 上电默认点亮（电源指示） |
| `led_green` / `green:status` | `off` | 默认熄灭，由上层应用控制 |
| `led_blue` / `blue:status` | `off` | 默认熄灭，由上层应用控制 |
| `led_2g` | `off` | 默认熄灭 |
| `led_5g` | `off` | 默认熄灭 |
| `mmc0::` | — | 由 mmc0 事件驱动 |

---

## 2. 原厂固件灯光控制逻辑

原厂固件（OpenWrt Chaos Calmer 15.05.1 定制版）的灯光控制由三层组成。

### 2.1 控制架构总览

```
开机上电
  │
  ├── DTS 默认: led_red = default-state=on → 红色指示灯亮
  │
  ├── /etc/init.d/led (START=96)
  │    读取 /etc/config/system 中的 config led 段
  │    → 该文件无 config led → 无实际操作
  │
  └── /etc/init.d/any_rclocal (START=98)
        for i in /usr/sbin/anywifi/rclocal.d/*; do $i &; done
        │
        ├── wan_net_stat.sh  ← ★ 主控制器
        ├── S99_os_netstat   ← 4G 模块 LED 管理
        ├── watchsystem_of_dog.sh ← 网络看门狗
        └── ...
```

### 2.2 主控制器：`wan_net_stat.sh`

这是原厂固件中唯一活跃的 LED 控制进程。它每隔 **1 秒** 检测 WAN 连通性并切换红/蓝灯。

**工作流程：**

```
每 1 秒循环:
  ├── ping baidu.com (3 次)
  │     ├── 成功 → led_red=灭, led_blue=亮 → 🔵 蓝灯
  │     └── 失败 → ping 114.114.114.114 (3 次)
  │           ├── 成功 → led_red=灭, led_blue=亮 → 🔵 蓝灯
  │           └── 失败 → led_red=亮, led_blue=灭 → 🔴 红灯
  └── sleep 1
```

**实际代码（`wan_net_stat.sh`）：**

```bash
while [ 1 ]; do
    ping -c 3 -w 3 -W 3 $detect_host1        # baidu.com
    if [ "$?" == "1" ]; then
        ping -c 3 -w 3 -W 3 $detect_host2    # 114.114.114.114
        if [ "$?" == "1" ]; then              # 两地址均不通
            echo 0 > /sys/class/leds/led_blue/brightness
            echo none > /sys/class/leds/led_blue/trigger
            echo 1 > /sys/class/leds/led_red/brightness
            echo default-on > /sys/class/leds/led_red/trigger
        else                                  # 仅 host2 通
            echo 0 > /sys/class/leds/led_red/brightness
            echo none > /sys/class/leds/led_red/trigger
            echo 1 > /sys/class/leds/led_blue/brightness
            echo default-on > /sys/class/leds/led_blue/trigger
        fi
    else                                      # host1 通
        echo 0 > /sys/class/leds/led_red/brightness
        echo none > /sys/class/leds/led_red/trigger
        echo 1 > /sys/class/leds/led_blue/brightness
        echo default-on > /sys/class/leds/led_blue/trigger
    fi
    sleep 1
done
```

> **⚠️ 注意**：此脚本每隔 1 秒执行一次，会覆盖所有手动写入的 brightness 值。
> 如需手动测试 LED，必须先 kill 此进程或用后台循环持续锁定。

**灯光含义（当前配置）：**

| 前面板颜色 | 含义 |
|---|---|
| 🔴 红灯常亮 | 网络不通（两个 ping 目标均不可达） |
| 🔵 蓝灯常亮 | 网络连通（至少一个 ping 目标可达） |

### 2.3 4G 模块 LED 管理：`S99_os_netstat`

`S99_os_netstat` 通过 UCI 配置 `anyos.led.*` 控制 4G 模块相关的指示灯：

| UCI 配置项 | 用途 |
|---|---|
| `anyos.led.internet_led_name` | 上网状态指示灯（设为 `default-on` / `none`） |
| `anyos.led.module_led_name` | 4G 模块指示灯（使用 netdev trigger） |
| `anyos.led.module_sim_led_name` | SIM 卡状态指示灯 |
| `anyos.led.module_rssi_name` | 4G 信号强度指示灯 |

**当前状态：上述 UCI 配置全部为空，该脚本的 LED 功能未启用。**

### 2.4 repacd LED 状态管理

`repacd`（Range Extender / AP Control Daemon）在 **RE（中继）模式**下管理 17 种 LED 状态模式。
它使用抽象名称 `led_0` / `led_1` 表示两个 LED，通过 `/etc/config/repacd` 配置。

**当前状态：`option Enable '0'`，此功能被禁用。**

| LEDState 模式 | `led_0` | `led_1` | 用户可见 |
|---|---|---|---|
| `Reset` | off | off | 全灭 |
| `NotAssociated` | 500ms 闪烁 | off | 红灯慢闪 |
| `AutoConfigInProgress` | 250ms 闪烁 | off | 红灯快闪 |
| `Measuring` | 250ms 闪烁 | 250ms 闪烁 | 红绿交替快闪 |
| `WPSTimeout` | 2000ms 亮, 1000ms 灭 | off | 红灯长闪 |
| `RE_MoveCloser` | on | off | 红灯常亮 |
| `RE_MoveFarther` | off | on | 绿灯常亮 |
| `RE_LocationSuitable` | on | on | 琥珀色 |
| `RE_BackhaulGood` | on | on | 琥珀色 |
| `RE_BackhaulFair` | on | off | 红灯常亮 |
| `RE_BackhaulPoor` | off | on | 绿灯常亮 |
| `RE_SwitchingBSTA` | 250ms 闪烁 | off | 红灯快闪 |
| `InCAPMode` | on | on | 琥珀色 |

### 2.5 WPS 按钮灯光影响

按 WPS 按钮时，`/etc/hotplug.d/button/50-wps` 会：

1. **kill** `wan_net_stat.sh`（停止自动检测）
2. 熄灭所有 LED（红/绿/蓝）
3. 设置 **蓝色 LED 以 1 秒周期闪烁**
4. 根据网口状态决定后续模式：
   - **CAP 模式**（网口有链接）：从 ROM 恢复 `wan_net_stat.sh`，LED 恢复为红/蓝指示灯
   - **RE 模式**（网口无链接）：**删除** `wan_net_stat.sh`，LED 由 `repacd` 管理

---

## 3. ImmortalWRT 差异与修复

### 3.1 LED 命名差异

| 物理 LED | 原厂 sysfs | ImmortalWRT sysfs |
|---|---|---|
| 🔴 红 | `led_red` | `red:status` |
| 🟢 绿 | `led_green` | `green:status` |
| 🔵 蓝 | `led_blue` | `blue:status` |

**两个固件的 sysfs 名称都正确对应物理颜色，不存在标签错位。**

### 3.2 GPIO 极性差异（真实问题）

两个固件的 GPIO 编号完全相同（50/70/69），但 DTS 中 `gpios` 属性的 **polarity flags 不同**：

| 固件 | GPIO flags | 含义 |
|---|---|---|
| 原厂 | `0x01` | `GPIO_ACTIVE_LOW`（低电平有效）✅ |
| ImmortalWRT | `0x00` | `GPIO_ACTIVE_HIGH`（高电平有效）❌ |

LED 硬件为**低电平有效**（common anode 共阳极接法，GPIO 灌电流时 LED 亮）：

| flags 配置 | `brightness=1` 时 GPIO 电平 | 物理 LED 状态 |
|---|---|---|
| `ACTIVE_LOW`（正确） | 低电平 (LOW) | ✅ **点亮** |
| `ACTIVE_HIGH`（错误） | 高电平 (HIGH) | ❌ **熄灭** |

**后果：** 在 ImmortalWRT 中，由于 flags 错误，`brightness` 值与实际灯光状态相反：

| 写入值 | 预期行为 | 实际结果（ImmortalWRT） |
|---|---|---|
| `brightness=1` | 亮 | ❌ 灭 |
| `brightness=0` | 灭 | ❌ 亮 |

### 3.3 上游源码提交

上游 DTS 文件：`target/linux/qualcommax/dts/ipq6000-link.dtsi`

- **openwrt/openwrt：** https://github.com/openwrt/openwrt/blob/main/target/linux/qualcommax/dts/ipq6000-link.dtsi
- **VIKINGYFY/immortalwrt：** https://github.com/VIKINGYFY/immortalwrt/blob/main/target/linux/qualcommax/dts/ipq6000-link.dtsi

首次引入 NN6000 支持的提交（含错误的 `GPIO_ACTIVE_HIGH`）：

```
提交: 0c068c6c2f7e6cf9f30a3f2f4161e67a9f919b65
作者: firedevel
提交者: Robert Marko <robimarko@gmail.com>
日期: 2026-03-21
描述: qualcommax: ipq60xx: add Link NN6000v1/v2 support
URL: https://github.com/openwrt/openwrt/commit/0c068c6c2f7e6cf9f30a3f2f4161e67a9f919b65
```

### 3.4 编译时修复

构建系统中的 `fix_nn6000_led_label()` 函数（`wrt_core/modules/target_fixes.sh`）
在编译时修正 DTS 中的 GPIO polarity flags：

**修复内容（`ipq6000-link.dtsi`）：**

```dts
// 修复前（三个节点的 flags 均为 GPIO_ACTIVE_HIGH 0x00）
led_status_red: status-red {
    gpios = <&tlmm 50 GPIO_ACTIVE_HIGH>;  // ← 错误
};
led_status_green: status-green {
    gpios = <&tlmm 70 GPIO_ACTIVE_HIGH>;  // ← 错误
};
led_status_blue: status-blue {
    gpios = <&tlmm 69 GPIO_ACTIVE_HIGH>;  // ← 错误
};

// 修复后（改为 GPIO_ACTIVE_LOW 0x01，并添加 active-low 属性）
led_status_red: status-red {
    active-low;
    gpios = <&tlmm 50 GPIO_ACTIVE_LOW>;   // ✓ 正确
};
led_status_green: status-green {
    active-low;
    gpios = <&tlmm 70 GPIO_ACTIVE_LOW>;   // ✓ 正确
};
led_status_blue: status-blue {
    active-low;
    gpios = <&tlmm 69 GPIO_ACTIVE_LOW>;   // ✓ 正确
};
```

修复后，`brightness=1` 正确点亮对应颜色的 LED。

> **⚠️ 搜索路径与修复逻辑说明（2026-08-01 更新）：**
>
> `fix_nn6000_led_label()` 早期版本只搜索 `files-6.18/` 和 `dts/` 目录，曾因上游结构变化
> 找不到文件导致修正静默失效（`grep -rl status-red` 无结果）。现版本按优先级搜索三类目录，
> 均支持 `.dts`/`.dtsi`/`.patch` 文件：
>
> 1. `target/linux/qualcommax/patches-[0-9]*/` — 内核补丁目录（版本无关，`patches-6.12` ~ `patches-7.0` 均匹配）
> 2. `target/linux/qualcommax/files-[0-9]*/` — 内核覆层目录（同上，版本无关）
> 3. `target/linux/qualcommax/dts/` — 原始 DTS 目录（`ipq6000-link.dtsi` 所在）
>
> **2026-08-01 修复**（详见 [CHANGES.md](./CHANGES.md) 第 13 节）：
>
> - **`read -d ''` 修复**：原始代码使用 `read -d ''`（NUL 分隔符）读取 `grep -l`（newline 分隔）的输出，
>   导致 `found_files` 数组永远为空，函数静默跳过所有修正。改为 `read -r`（newline 分隔）。
> - **文件名过滤**：原 `grep -rl "status-red"` 匹配所有含红色状态灯的设备（如 `ipq6010-philips.dtsi`、
>   `ipq8070-rm2-6.dts`），现在仅保留文件名含 `link`/`nn6000` 的文件，避免误伤其他 IPQ60xx 设备。
> - **版本无关 glob**：将硬编码的 `patches-6.*` / `files-6.*` 改为 `patches-[0-9]*` / `files-[0-9]*`，
>   内核升级到 7.x 或更高版本也不会静默失效。
> - **两阶段 sed**：先修正 `GPIO_ACTIVE_HIGH` → `GPIO_ACTIVE_LOW`，再插入 `active-low;` 属性。
>   两个阶段对 `.patch` 文件（行前缀 `+`）和 raw `.dts`/`.dtsi` 文件使用不同的匹配模式，
>   确保补丁格式不被破坏。
> - **移除死代码**：删除了永不匹配的 `s/ [0-9]\+>$/ 1>/` sed 模式（DTS 使用宏名而非数值）。
> - **`active-low;` 作用说明**：NN6000 的 LED 由 `gpio-leds` 驱动管理（`compatible = "gpio-leds"`），
>   该驱动的极性控制 **仅取决于 gpios flags**（`GPIO_ACTIVE_LOW`），不读取 `active-low;` 属性。
>   保留该属性作为防御性编程（其他 LED 驱动如 PWM LED 的确会读取它），但对 NN6000 无实际功能影响。

### 3.5 ImmortalWRT 无自动恢复

与原厂固件不同，ImmortalWRT **没有** `wan_net_stat.sh` 之类的周期性 LED 覆盖进程。
手动写入 brightness 值后会一直保持，直到下次写入或重启。

### 3.6 led-ctrl 定制服务修复记录（2026-08-01）

本仓库提供的 `/etc/init.d/led-ctrl` 服务替代原厂的 `wan_net_stat.sh`，实现 5 状态 RGB LED 控制。
以下为 2026-08-01 全面审查后发现并修复的问题：

| 问题 | 严重度 | 影响 | 修复 |
|---|---|---|---|
| `read -d ''` 导致 DTS 修正从未生效 | 🔴 致命 | `grep -l` 输出为 newline 分隔，`read -d ''` 等待 NUL 字节，导致 `found_files` 数组永远为空，整个 `fix_nn6000_led_label` 静默跳过 | 改为 `read -r`（newline 分隔） |
| SIGHUP 无限递归 | 🔴 严重 | daemon 在 reload 时向自身发 HUP，陷入无限信号处理循环，主状态机永远卡死 | daemon trap 改为仅重置 `_MODE=""`，`reload_service()` 仅负责向 daemon 发 HUP |
| 误伤其他 IPQ60xx 设备 DTS | 🟠 高 | `grep -rl "status-red"` 匹配 philips、rm2 等设备，修改其 LED 极性可能破坏未知硬件的 LED 行为 | 添加文件名过滤 `*link*\|*nn6000*`，仅处理 NN6000/Link 文件 |
| `.patch` 文件 `active-low;` 缺 `+` 前缀 | 🟠 高 | 若 DTS 以补丁形式提供，插入的行缺少 `+` 前缀，破坏补丁格式 | 两阶段 sed：区分 `+` 行与普通行分别处理 |
| CI 验证了错误的文件 | 🟡 中 | `find \| head -1` 字母序选中 `ipq6010-philips.dtsi`，从未验证实际 NN6000 文件 | 4a. 独立查找 `*link*`/`*nn6000*` 文件并验证；4b. 精确检查其他设备 LED 节点是否被误伤 |
| 硬编码内核版本 `patches-6.*` | 🟡 中 | 内核升级到 7.x 后 glob 静默失效 | 改为 `patches-[0-9]*` / `files-[0-9]*` |
| `((count++))` 导致 install 标记误报失败 | 🟡 中 | `count=0` 时 `((count++))` 返回 exit 1，触发 `|| _mark_fail` 覆盖已写入的 OK 标记（`file_led-ctl`、`file_990_argon` 均被误报） | 改为 `((++count))`（前自增），并将 `_mark_ok` 移到 block 末尾作为返回值 |
| 非致命 grep 错误噪音 | 🟢 低 | `set -o errtrace` 下 grep 无匹配返回 1 触发 ERR trap，日志中出现 `Error occurred at line...` | `grep ... || true` 抑制 |
| 启动默认红灯 | 🟢 低 | 服务启动时 `set_mode "no-link"` 显示红灯，不符用户预期 | 改为 `set_mode "connected"`（绿灯常亮） |

> **根本原因**：第 1 个问题（`read -d ''`）是 `fix_nn6000_led_label` **从未生效**的根因 —
> 它导致 found_files 数组为空，函数直接 return。这也解释了为什么之前的 CI 构建日志中
> LED 修正始终不出现，以及为什么问题 3（误伤）在上游 DTS 中未被发现。
> 第 2 个问题（SIGHUP 递归）导致 led-ctrl daemon 在 WAN 状态变化后卡死。
> 第 8 个问题（`((count++))`）导致 `file_led-ctl` 和 `file_990_argon` 的 install 被误报为失败。

---

## 4. 手动控制 LED

### 4.1 原厂固件（Chaos Calmer）

```bash
# 注意: wan_net_stat.sh 会每秒覆盖，需先 kill
kill $(pgrep wan_net_stat)

# 开红灯 (PWM 最大值 255)
echo 255 > /sys/class/leds/led_red/brightness
# 关红灯
echo 0 > /sys/class/leds/led_red/brightness

# 开绿灯
echo 255 > /sys/class/leds/led_green/brightness
# 开蓝灯
echo 255 > /sys/class/leds/led_blue/brightness
```

### 4.2 ImmortalWRT（修复前）

由于 GPIO flags 错误的临时绕过方法（`brightness` 值反相）：

```bash
# "开"红灯（实际写入反相值 0）
echo 0 > /sys/class/leds/red:status/brightness
# "关"红灯
echo 1 > /sys/class/leds/red:status/brightness

# "开"绿灯
echo 0 > /sys/class/leds/green:status/brightness
# "开"蓝灯
echo 0 > /sys/class/leds/blue:status/brightness
```

### 4.3 ImmortalWRT（修复 flags 后）

修复后 `brightness=1` 表示亮，与常规行为一致：

```bash
# 开红灯
echo 1 > /sys/class/leds/red:status/brightness
# 关红灯
echo 0 > /sys/class/leds/red:status/brightness
```

### 4.4 利用 custom-boot 框架持久化

设备支持 `/etc/custom-boot.d/` 开机自启脚本（`find / -maxdepth 4 -name "custom-boot.d"` 自动发现，
需 `.boot-enabled` 触发文件）：

```bash
mkdir -p /etc/custom-boot.d/01-led-fix
touch /etc/custom-boot.d/.boot-enabled
cat > /etc/custom-boot.d/01-led-fix/apply.sh << 'EOF'
#!/bin/sh
# 绿灯常亮（适用于 flags 已修复的 ImmortalWRT）
echo 1 > /sys/class/leds/green:status/brightness
echo 0 > /sys/class/leds/red:status/brightness
EOF
chmod +x /etc/custom-boot.d/01-led-fix/apply.sh
```

---

## 5. 相关文件清单

### 5.1 sysfs 接口

| 路径 | 说明 |
|---|---|
| `/sys/class/leds/led_red/brightness` | 红灯亮度（原厂 0-255） |
| `/sys/class/leds/led_green/brightness` | 绿灯亮度 |
| `/sys/class/leds/led_blue/brightness` | 蓝灯亮度 |
| `/sys/class/leds/*/trigger` | LED 触发器（none/timer/default-on/netdev） |

### 5.2 原厂固件控制脚本

原厂固件中的原始脚本已提取到仓库中，可直接参考：

| 仓库路径 | 原始路径 | 作用 |
|---|---|---|
| `docs/stock-firmware/led/wan_net_stat.sh` | `/usr/sbin/anywifi/rclocal.d/wan_net_stat.sh` | ★ 主控制器，每秒 ping 切换红/蓝灯 |
| `docs/stock-firmware/led/50-wps-hotplug.sh` | `/etc/hotplug.d/button/50-wps` | WPS 按钮时 kill wan_net_stat.sh 并蓝灯闪烁 |
| `docs/stock-firmware/led/repacd-led.sh` | `/lib/functions/repacd-led.sh` | repacd LED 状态管理函数库 |
| `docs/stock-firmware/led/led.init` | `/etc/init.d/led` | OpenWrt 标准 LED 框架（无配置时无操作） |
| `docs/stock-firmware/led/any_rclocal.init` | `/etc/init.d/any_rclocal` | 启动 rclocal.d 目录下所有后台脚本 |
| — | `/usr/sbin/anywifi/rclocal.d/S99_os_netstat` | 4G 模块 LED 管理（UCI 未配置，未启用） |
| — | `/etc/init.d/repacd` | Range Extender 守护进程（当前禁用） |

### 5.3 配置文件

| 文件 | 作用 |
|---|---|
| `/etc/config/repacd` | repacd LED 状态配置（17 种模式） |
| `/etc/config/anyos` | 系统配置（含 LED 控制 UCI，当前为空） |
| `/etc/config/anyos_netwatchdog` | 网络看门狗配置（ping 目标地址等） |
| `/etc/config/system` | 系统配置（可含 config led 段） |

### 5.4 设备树

| 路径 | 说明 |
|---|---|
| `/proc/device-tree/leds/` | 设备树 LED 节点（仅 ImmortalWRT） |
| `/sys/bus/platform/drivers/leds-gpio/soc:leds/of_node/` | DTS LED 节点（仅原厂固件） |

---

## 6. 文档修订记录

| 日期 | 修订内容 |
|---|---|
| 2026-08-01 | **全面审查与修复**（详见 3.4、3.6 节）：
| | 致命：`read -d ''` → `read -r`（DTS 修正从未生效的根因），SIGHUP 递归卡死 daemon
| | 高：文件名过滤防误伤 philips/rm2 设备，`.patch` 格式兼容
| | 中：CI 独立验证 + 精确误伤检查（sed 节点内），内核版本无关 glob，`((count++))` install 标记修复
| | 低：led-ctl brightness 统一，grep 噪音抑制，启动默认改绿灯常亮 |
| 2026-07-19 | 重写全文。修正了错误结论（"标签反了"），更正为 GPIO 极性 flags 问题。
| | 补充两个固件交叉验证的实测数据。增加原厂 `wan_net_stat.sh` 控制逻辑分析。 |
| 2026-07-18 | 初版。包含有误的"标签反置"结论。 |