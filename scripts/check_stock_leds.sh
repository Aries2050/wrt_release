#!/bin/sh
# 原厂固件 LED 控制逻辑全面检查脚本
# 用法: ssh root@192.168.7.1 < check_stock_leds.sh

echo "=========================================="
echo "1. 当前 LED 状态"
echo "=========================================="
for led in /sys/class/leds/*/; do
  name=$(basename "$led")
  echo "--- $name ---"
  cat "${led}trigger" 2>/dev/null
  echo "brightness: $(cat ${led}brightness 2>/dev/null)"
  echo "max_brightness: $(cat ${led}max_brightness 2>/dev/null)"
done

echo ""
echo "=========================================="
echo "2. UCI 配置"
echo "=========================================="
echo "--- anyos ---"
uci show anyos 2>&1
echo ""
echo "--- system (led) ---"
uci show system 2>&1 | grep -i 'led\|trigger\|sysfs'
echo ""
echo "--- anyos_netwatchdog ---"
uci show anyos_netwatchdog 2>&1

echo ""
echo "=========================================="
echo "3. 开机自启"
echo "=========================================="
ls -la /etc/rc.d/ 2>/dev/null | grep -iE 'netstat|os_net|led'

echo ""
echo "=========================================="
echo "4. Cron"
echo "=========================================="
cat /etc/crontabs/root 2>/dev/null || echo "(无)"

echo ""
echo "=========================================="
echo "5. repacd"
echo "=========================================="
which repacd 2>/dev/null || echo "not found"
ls -la /usr/sbin/repacd /sbin/repacd /usr/bin/repacd 2>/dev/null || echo "no binary"

echo ""
echo "=========================================="
echo "6. /etc/config/system LED 段"
echo "=========================================="
grep -A5 'config led' /etc/config/system 2>/dev/null || echo "(无)"

echo ""
echo "=========================================="
echo "7. S99_os_netstat LED 关键行"
echo "=========================================="
grep -n 'led\|trigger\|brightness\|default-on\|netdev' /usr/sbin/anywifi/rclocal.d/S99_os_netstat 2>/dev/null

echo ""
echo "=========================================="
echo "8. UCI 中所有含 led 的配置"
echo "=========================================="
uci show 2>/dev/null | grep -i 'led'

echo ""
echo "=========================================="
echo "9. /etc/config/anyos 含 led 的行"
echo "=========================================="
grep -ni 'led' /etc/config/anyos 2>/dev/null || echo "(无)"

echo ""
echo "=========================================="
echo "10. /etc/config/anyos_netwatchdog"
echo "=========================================="
cat /etc/config/anyos_netwatchdog 2>/dev/null || echo "(无)"

echo ""
echo "=========================================="
echo "11. ps 中与 LED 控制相关的进程"
echo "=========================================="
ps 2>/dev/null | grep -iE 'led|netstat|event|watch' | grep -v grep

echo ""
echo "=========================================="
echo "12. inittab"
echo "=========================================="
cat /etc/inittab 2>/dev/null || echo "(无)"

echo ""
echo "=========================================="
echo "13. Wan_net_stat.sh LED 相关"
echo "=========================================="
grep -n 'led\|trigger\|brightness' /usr/sbin/anywifi/rclocal.d/wan_net_stat.sh 2>/dev/null || echo "(无)"

echo ""
echo "=========================================="
echo "14. device_event_daemon.sh LED 相关"
echo "=========================================="
grep -n 'led\|trigger\|brightness' /usr/local/rdcwifi/device_event_daemon.sh 2>/dev/null | head -30 || echo "(无)"

echo ""
echo "=========================================="
echo "15. dmz.sh / reboot_cron.sh LED 相关"
echo "=========================================="
grep -n 'led\|trigger\|brightness' /usr/local/rdcwifi/dmz.sh 2>/dev/null | head -10 || echo "(无)"
grep -n 'led\|trigger\|brightness' /usr/local/rdcwifi/reboot_cron.sh 2>/dev/null | head -10 || echo "(无)"
grep -n 'led\|trigger\|brightness' /usr/local/rdcwifi/device_qos.sh 2>/dev/null | head -10 || echo "(无)"

echo ""
echo "=========================================="
echo "16. anyos_data_collect LED 相关"
echo "=========================================="
grep -n 'led\|trigger\|brightness' /usr/sbin/anywifi/rclocal.d/anyos_data_collect 2>/dev/null | head -20 || echo "(无)"
