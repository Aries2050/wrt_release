#!/bin/sh
# === repacd LED 状态管理函数库 ===
# 路径: /lib/functions/repacd-led.sh
# 功能: 读取 /etc/config/repacd 中的 LEDState 配置，
#       设置对应 sysfs LED 的 trigger/brightness/delay
#
# 映射方式:
#   配置文件使用抽象名称 led_0 / led_1，通过 /etc/config/system 中
#   config led 'led_0' 的 sysfs 属性映射到实际 LED 名称。
#
# 当前状态: repacd 被禁用 (Enable=0)，此库未加载。
#
# 来源: Link NN6000 原厂固件 (OpenWrt Chaos Calmer 15.05.1)
# Copyright (c) 2015 Qualcomm Atheros, Inc.

. /lib/functions.sh

# 根据抽象名称查找 sysfs 路径
# 输入: $1 - 抽象名称 (如 led_0, led_1)
# 输出: $2 - sysfs 路径变量
__repacd_led_get_path() {
    local led_name=$1 sysfs_name
    config_load system
    config_get sysfs_name "$led_name" 'sysfs' ''
    if [ -n "$sysfs_name" ]; then
        eval "$2=/sys/class/leds/$sysfs_name"
        return 0
    else
        return 1
    fi
}

# 设置单个 LED 状态
__repacd_led_set_state() {
    local state_name=$1 index=$2
    local name trigger brightness delay_on delay_off
    local sysfs_path

    config_load repacd
    config_get name "$state_name" "Name_${index}" ''
    if [ -n "$name" ]; then
        config_get trigger "$state_name" "Trigger_${index}" ''
        config_get brightness "$state_name" "Brightness_${index}" ''
        if [ "$trigger" = 'timer' ]; then
            config_get delay_on "$state_name" "DelayOn_${index}" ''
            config_get delay_off "$state_name" "DelayOff_${index}" ''
        fi

        __repacd_led_get_path "$name" sysfs_path

        if [ -n "$trigger" ] && [ -n "$name" ]; then
            echo "$trigger" > "/sys/class/leds/$name/trigger"

            if [ "$trigger" = 'timer' ] && [ -n "$delay_on" ] && [ -n "$delay_off" ]; then
                echo "$delay_on" > "/sys/class/leds/$name/delay_on"
                echo "$delay_off" > "/sys/class/leds/$name/delay_off"
            fi
        fi
    fi
}

# 更新所有 LED 到指定状态
# 输入: $1 - 状态名称 (对应 /etc/config/repacd 中的 LEDState section 名)
repacd_led_set_states() {
    for index in $(seq 1 3)
    do
        echo "mesh stat : $1" > /tmp/mesh_stat.txt
        __repacd_led_set_state "$1" "$index"
    done
}
