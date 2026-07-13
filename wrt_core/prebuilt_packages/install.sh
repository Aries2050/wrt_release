#!/bin/sh
work_dir=$(pwd)
script_dir="$(cd "$( dirname "$0" )" && pwd)"

cd ${work_dir}

if [ "$(opkg print-architecture | sed -n 's/arch \(\S\+\) 10/\1/pg')" != "aarch64_cortex-a53" ]; then
	add_arch=1
	cat >> /etc/opkg.conf <<-EOF1
		# qbt add start
		$(opkg print-architecture)
		arch aarch64_cortex-a53 1
		# qbt add end"
	EOF1
fi

case "$1" in
	install)
		shift
		cp ${script_dir}/key/527ca1333af7875e /etc/opkg/keys
		sed -i "\$asrc\/gz openwrt_qbt file:\/\/$(echo ${script_dir}/pkgs | sed 's/\//\\\//g')" /etc/opkg/customfeeds.conf

		echo "-------------------------------------------"
		opkg print-architecture
		echo "-------------------------------------------"

		mkdir -p /var/opkg-lists/
		cp ${script_dir}/pkgs/Packages.gz /var/opkg-lists/openwrt_qbt
		cp ${script_dir}/pkgs/Packages.sig /var/opkg-lists/openwrt_qbt.sig

		[ "$#" -gt 0 ] || set -- qbittorrent luci-app-qbittorrent luci-i18n-qbittorrent-zh-cn
		opkg install $@
		sed -i "/src\/gz openwrt_qbt file:\/\/$(echo ${script_dir}/pkgs | sed 's/\//\\\//g')/d" /etc/opkg/customfeeds.conf
		rm -rf /etc/opkg/keys/527ca1333af7875e
	;;
	remove)
		opkg --force-removal-of-dependent-packages $@
	;;
	*)
		echo "Usage:"
		echo "	$0 [sub-command]"
		echo ""
		echo "Commands:"
		echo "	install			Install qbittorrent and its depends"
		echo "	remove <pkgs>		Uninstall pkgs"
		echo ""
	;;
esac

[ "$add_arch" != 1 ] || sed -i '/# qbt add start/{:a;N;/# qbt add end/!ba;d}' /etc/opkg.conf
