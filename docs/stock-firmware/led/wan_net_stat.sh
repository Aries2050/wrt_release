#!/bin/sh
# === 原厂固件 LED 主控制器 ===
# 路径: /usr/sbin/anywifi/rclocal.d/wan_net_stat.sh
# 启动方式: /etc/init.d/any_rclocal (START=98) 后台自动启动
# 功能: 每 1 秒检测 WAN 连通性，切换 led_red / led_blue
#
# LED 含义:
#   🔴 红灯 = 网络不通 (两个 ping 目标均不可达)
#   🔵 蓝灯 = 网络连通 (至少一个 ping 目标可达)
#
# 注意:
#   - 此脚本每隔 1 秒覆盖一次 LED 状态，手动写入会立即被覆盖
#   - 测试前需 kill $(pgrep wan_net_stat)
#
# 来源: Link NN6000 原厂固件 (OpenWrt Chaos Calmer 15.05.1)

if [ -e "/var/run/${0##*/}.pid" ] ;then
        if [ -e "/proc/$(cat /var/run/${0##*/}.pid)" ];then
                echo "${0##*/} is already running"
                return 2
        fi
fi
echo "$$" > /var/run/${0##*/}.pid

my_uci_get(){
        if [ "$(uci get "$1" 2>&1 | grep "Entry not found" | wc -l)" == "1" ];then
                debug_echo "$1 not found"  1>&2
        else
                echo -n "$(uci get "$1")"
        fi
}

while [ 1 ]
do
        detect_host1="$(my_uci_get anyos_netwatchdog.device.detect_host1)"
        detect_host2="$(my_uci_get anyos_netwatchdog.device.detect_host2)"
        [ "$detact_host1" == "" ] && detect_host1="114.114.114.114"
        [ "$detact_host2" == "" ] && detect_host2="8.8.8.8"

        ping -c 3 -w 3 -W 3 $detect_host1
        if [ "$?" == "1" ];then
                echo "ping detect_host1 failed"
                ping -c 3 -w 3 -W 3 $detect_host2
                if [ "$?" == "1" ];then
                        echo 0 > /sys/class/leds/led_blue/brightness
                        echo none > /sys/class/leds/led_blue/trigger
                        echo 1 > /sys/class/leds/led_red/brightness
                        echo default-on > /sys/class/leds/led_red/trigger
                else
                        echo 0 > /sys/class/leds/led_red/brightness
                        echo none > /sys/class/leds/led_red/trigger
                        echo 1 > /sys/class/leds/led_blue/brightness
                        echo default-on > /sys/class/leds/led_blue/trigger
                fi
        else
                echo 0 > /sys/class/leds/led_red/brightness
                echo none > /sys/class/leds/led_red/trigger
                echo 1 > /sys/class/leds/led_blue/brightness
                echo default-on > /sys/class/leds/led_blue/trigger
        fi

        sleep 1

done
