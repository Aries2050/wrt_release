#!/bin/sh
# === WPS 按钮热插拔脚本（LED 相关部分）===
# 路径: /etc/hotplug.d/button/50-wps
# 触发条件: ACTION="pressed" && BUTTON="#wps"
#
# LED 行为:
#   1. kill wan_net_stat.sh（停止自动检测）
#   2. 熄灭所有 LED（led_red, led_green, led_blue）
#   3. 蓝色 LED 以 1 秒周期闪烁（timer trigger）
#   4. 根据网口状态切换模式:
#      - CAP 模式（port 2 有链接）: 从 ROM 恢复 wan_net_stat.sh，运行 CAP 配置
#      - RE 模式（port 2 无链接）: 删除 wan_net_stat.sh，运行 RE 配置
#
# 来源: Linksys NN6000 原厂固件 (OpenWrt Chaos Calmer 15.05.1)
# 完整文件包含 WPS 和 SON 逻辑，此处仅保留 LED 控制部分

if [ "$ACTION" = "pressed" -a "$BUTTON" = "#wps" ]; then
        echo "WPS PUSH BUTTON EVENT DETECTED" > /dev/console

        # 1. 停止 wan_net_stat.sh 自动检测
        pid=$(ps -ww | grep wan_net_stat | grep -v grep | awk '{print $1}')
        kill -9 $pid

        # 2. 熄灭所有 LED
        echo none > /sys/class/leds/led_green/trigger
        echo 0 > /sys/class/leds/led_green/brightness

        echo none > /sys/class/leds/led_red/trigger
        echo 0 > /sys/class/leds/led_red/brightness

        # 3. 蓝色 LED 1 秒闪烁
        echo timer > /sys/class/leds/led_blue/trigger
        echo 255 > /sys/class/leds/led_blue/brightness
        echo 1000 > /sys/class/leds/led_blue/delay_on
        echo 1000 > /sys/class/leds/led_blue/delay_off

        # 4. 根据网口状态切换 CAP/RE 模式
        is=$(swconfig dev switch0 show | grep "link: port:2 link:up" | wc -l)
        if [ "$is" == "1" ];then
                # CAP 模式: 从 ROM 恢复 wan_net_stat.sh
                cp /rom/usr/sbin/anywifi/rclocal.d/wan_net_stat.sh \
                   /usr/sbin/anywifi/rclocal.d/wan_net_stat.sh
                sh /etc/config/CAP/cap.sh > /dev/null 2>&1
                sh /etc/config/CAP/hide_mesh_ap.sh > /dev/null 2>&1 &
        else
                # RE 模式: 删除 wan_net_stat.sh
                rm /usr/sbin/anywifi/rclocal.d/wan_net_stat.sh
                sh /etc/config/RE/re.sh > /dev/null 2>&1
        fi
fi
