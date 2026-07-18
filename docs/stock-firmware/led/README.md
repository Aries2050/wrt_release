# 原厂固件 LED 控制脚本

> 提取自 Linksys NN6000 原厂固件 (OpenWrt Chaos Calmer 15.05.1)
> 提取日期: 2026-07-19

## 文件清单

| 文件 | 原始路径 | 作用 |
|---|---|---|
| `wan_net_stat.sh` | `/usr/sbin/anywifi/rclocal.d/wan_net_stat.sh` | ★ **主控制器**，每秒 ping 检测 WAN 连通性，切换红/蓝灯 |
| `50-wps-hotplug.sh` | `/etc/hotplug.d/button/50-wps` | WPS 按钮按下时 kill wan_net_stat.sh，蓝色 LED 闪烁 |
| `repacd-led.sh` | `/lib/functions/repacd-led.sh` | repacd LED 状态管理函数库（当前被禁用） |
| `led.init` | `/etc/init.d/led` | OpenWrt 标准 LED 初始化框架（START=96） |
| `any_rclocal.init` | `/etc/init.d/any_rclocal` | 后台启动 rclocal.d 目录下所有脚本（START=98） |

## 控制架构

```
开机
  │
  ├── DTS: led_red = default-state=on → 🔴 红灯亮
  │
  ├── /etc/init.d/led (START=96)
  │     → /etc/config/system 中无 config led → 无操作
  │
  └── /etc/init.d/any_rclocal (START=98)
        → 后台启动 rclocal.d/* 下的所有脚本:
            ├── wan_net_stat.sh    ← 主控制器（每秒 ping）
            ├── S99_os_netstat     ← 4G 模块 LED（UCI 未配置）
            └── watchsystem_of_dog.sh ← 网络看门狗
```

## WPS 按钮模式切换

按 WPS 按钮时：

1. **kill** `wan_net_stat.sh`
2. 熄灭红/绿灯，蓝色 LED 1 秒周期闪烁
3. 根据网口状态：
   - **CAP 模式**（port 2 有链接）：从 ROM 恢复 `wan_net_stat.sh`，LED 恢复红/蓝指示
   - **RE 模式**（port 2 无链接）：**删除** `wan_net_stat.sh`，由 `repacd` 管理

## 相关文档

参见 [`../nn6000-led-config.md`](../nn6000-led-config.md) 获取完整的 LED 配置分析和 ImmortalWRT 修正说明。
