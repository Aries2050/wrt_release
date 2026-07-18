# NN6000 原厂固件特征指纹

> **用途**: 通过远程或本地手段快速判断一台 NN6000 设备是否运行原厂固件（基于 OpenWrt Chaos Calmer 15.05.1 的 Linksys/ZBT 定制固件）。
> **适用对象**: 与 ImmortalWRT 的固件识别区分。

---

## 1. Web 页面特征（无需 SSH，浏览器访问即可）

### 1.1 网页标题/App 名称

访问 `http://192.168.7.1/`，查看页面源码中的：

```html
<meta name=apple-mobile-web-app-title content=aclink>
```

`content=aclink` 是原厂固件独有的 SPA 应用名，ImmortalWRT 无此标记。

### 1.2 接口查询法

```bash
# 请求 menu_conf.json，包含 "corporation": "ZBT"
curl -s http://192.168.7.1/menu_conf.json | grep corporation
# 返回: "corporation": "ZBT"

# 请求主页面，检查 Vue SPA 特征
curl -s http://192.168.7.1/ | grep -o 'content=aclink'
# 返回: content=aclink

# 检查自定义 API 端点是否存在
curl -s -o /dev/null -w "%{http_code}" http://192.168.7.1/cgi-bin/webapi
# 返回: 200 (原厂)  vs  404 (ImmortalWRT)
```

### 1.3 快速判断命令（一键）

```bash
# 任意一项匹配即可认定
curl -s http://<IP>/menu_conf.json 2>/dev/null | grep -q '"corporation":.*"ZBT"' && echo "STOCK" || echo "NOT_STOCK"
```

---

## 2. SSH 登录特征（需 root 权限）

### 2.1 系统版本

```bash
cat /etc/openwrt_release
```

| 字段 | 原厂固件 | ImmortalWRT |
|---|---|---|
| `DISTRIB_ID` | `OpenWrt` | `ImmortalWrt` |
| `DISTRIB_RELEASE` | `Chaos Calmer` | `SNAPSHOT` |
| `DISTRIB_CODENAME` | `chaos_calmer` | — |
| `DISTRIB_REVISION` | `unknown` | `r0-xxxxxxxx` |

### 2.2 设备树模型

```bash
cat /proc/device-tree/model
```

| 固件 | 输出 |
|---|---|
| 原厂 | `Qualcomm Technologies, Inc. IPQ6018/AP-CP03-C1` |
| ImmortalWRT | 不同（取决于上游 DTS） |

### 2.3 LED sysfs 命名

```bash
ls /sys/class/leds/
```

| 固件 | LED 名称 |
|---|---|
| **原厂** | `led_red` `led_green` `led_blue` `led_2g` `led_5g` |
| **ImmortalWRT** | `red:status` `green:status` `blue:status` `mmc0::` |

### 2.4 DTS LED 节点结构

```bash
ls /sys/bus/platform/drivers/leds-gpio/soc:leds/of_node/
```

| 固件 | 节点命名方式 |
|---|---|
| **原厂** | `led@50` `led@69` `led@70` `led@35` `led@37`（以 GPIO 号命名） |
| **ImmortalWRT** | `status-red` `status-green` `status-blue`（以功能命名） |

### 2.5 Leds-gpio 极性标志

```bash
# 检查 RGB LED 的 GPIO flags
hexdump -C /sys/bus/platform/drivers/leds-gpio/soc:leds/of_node/led@50/gpios
```

| 固件 | GPIO flags |
|---|---|
| **原厂** | `0x01`（低电平有效，ACTIVE_LOW） |
| **ImmortalWRT** | `0x00`（高电平有效，ACTIVE_HIGH） |

### 2.6 固件进程特征

```bash
ls /etc/init.d/ | grep -E 'repacd|wsplcd|hyd|acd'
```

| 固件 | 特有服务 |
|---|---|
| **原厂** | `repacd` `wsplcd` `hyd` `hyfi-bridging` `acd` `lbd` 等 Linksys 定制服务 |
| **ImmortalWRT** | 无上述服务 |

---

## 3. 自动检测脚本

```bash
#!/bin/sh
# nn6000-stock-detect.sh — 检测 NN6000 是否为原厂固件
# 用法: ./nn6000-stock-detect.sh <IP地址>

IP="${1:-192.168.7.1}"

echo ">>> 检测 $IP ..."

# 3.1 Web 特征检测
WEB_STOCK=0
if curl -s --connect-timeout 3 "http://$IP/menu_conf.json" 2>/dev/null | \
   grep -q '"corporation":.*"ZBT"'; then
    echo "[PASS] Web: menu_conf.json 包含 corporation=ZBT"
    WEB_STOCK=1
elif curl -s --connect-timeout 3 "http://$IP/" 2>/dev/null | \
     grep -q 'content=aclink'; then
    echo "[PASS] Web: 页面包含 content=aclink"
    WEB_STOCK=1
else
    echo "[FAIL] Web: 未检测到原厂特征"
fi

# 3.2 SSH LED 命名检测
SSH_STOCK=0
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
       "root@$IP" 'ls /sys/class/leds/' 2>/dev/null | \
   grep -q 'led_red'; then
    echo "[PASS] SSH: LED 命名为 led_red 风格"
    SSH_STOCK=1
else
    echo "[FAIL] SSH: LED 命名非原厂风格"
fi

# 3.3 SSH 版本检测
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
       "root@$IP" 'cat /etc/openwrt_release' 2>/dev/null | \
   grep -q 'Chaos Calmer'; then
    echo "[PASS] SSH: 系统为 Chaos Calmer"
    SSH_STOCK=1
fi

if [ "$WEB_STOCK" = 1 ] || [ "$SSH_STOCK" = 1 ]; then
    echo ""
    echo "=== 结论: 原厂固件 ==="
else
    echo ""
    echo "=== 结论: 非原厂固件（可能是 ImmortalWRT 或其它第三方固件）==="
fi
```

---

## 4. 快速参考表

| 检测方式 | 检测项 | 原厂特征 | 信任度 |
|---|---|---|---|
| Web | `corporation` | `"ZBT"` | ⭐⭐⭐ |
| Web | `apple-mobile-web-app-title` | `aclink` | ⭐⭐⭐ |
| Web | `/cgi-bin/webapi` | 存在 (200) | ⭐⭐ |
| SSH | `DISTRIB_ID` | `OpenWrt` | ⭐⭐⭐ |
| SSH | LED 命名 | `led_red` 风格 | ⭐⭐⭐ |
| SSH | DTS LED 节点 | `led@50` 等 GPIO 编号 | ⭐⭐⭐ |
| SSH | GPIO flags | `0x01` (ACTIVE_LOW) | ⭐⭐⭐ |
| SSH | Linksys 服务 | `repacd` `wsplcd` 等 | ⭐⭐⭐ |

### 4.2 LED 行为特征

原厂固件有一个独特的 LED 行为：`wan_net_stat.sh` 每隔 1 秒检测网络连通性并切换红/蓝灯。

```bash
# 在网络不通的情况下，手动关灯会立即被恢复:
echo none > /sys/class/leds/led_red/trigger
echo 0 > /sys/class/leds/led_red/brightness
sleep 2
cat /sys/class/leds/led_red/brightness
# 原厂: 2秒后 brightness=255 (被恢复)
# ImmortalWRT: brightness=0 (保持不变)
```

### 4.3 LED 用途差异

| 特征 | 原厂固件 | ImmortalWRT |
|---|---|---|
| `led_red` (GPIO 50) | 🔴 通电即亮（断网红灯） | 由应用控制 |
| `led_blue` (GPIO 69) | 🔵 有网亮蓝灯 | 由应用控制 |
| `led_green` (GPIO 70) | 默认熄灭（repacd 控制） | 由应用控制 |

> **注意**: 部分原厂固件可能存在 Web 界面 HTTPS 重定向，curl 测试时需加 `-k` 跳过证书验证。
