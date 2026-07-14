#!/bin/sh
# ⭐ 本地定制：管理预编译 IPK 包和 HDSentinel 部署

set -e

work_dir=$(pwd)
script_dir="$(cd "$( dirname "$0" )" && pwd)"
PACKAGE_DIR="$script_dir/pkgs"

cd ${work_dir}

# ===================== 通用函数 =====================

list_packages() {
    echo "Available packages:"
    if [ -d "$PACKAGE_DIR" ]; then
        ls "$PACKAGE_DIR"/*.ipk 2>/dev/null | while read f; do
            echo "  $(basename "$f")"
        done
    fi
}

# ===================== qBittorrent =====================

install_qbittorrent() {
    local add_arch=0

    if [ "$(opkg print-architecture | sed -n 's/arch \(\S\+\) 10/\1/pg')" != "aarch64_cortex-a53" ]; then
        add_arch=1
        cat >> /etc/opkg.conf <<-EOF1
            # qbt add start
            $(opkg print-architecture)
            arch aarch64_cortex-a53 1
            # qbt add end
EOF1
    fi

    cp "$script_dir/key/527ca1333af7875e" /etc/opkg/keys
    local escaped_dir=$(echo "$script_dir/pkgs" | sed 's/\//\\\//g')
    sed -i "\$asrc\/gz openwrt_qbt file:\/\/${escaped_dir}" /etc/opkg/customfeeds.conf 2>/dev/null

    mkdir -p /var/opkg-lists/
    cp "$script_dir/pkgs/Packages.gz" /var/opkg-lists/openwrt_qbt 2>/dev/null
    cp "$script_dir/pkgs/Packages.sig" /var/opkg-lists/openwrt_qbt.sig 2>/dev/null

    [ "$#" -gt 0 ] || set -- qbittorrent luci-app-qbittorrent luci-i18n-qbittorrent-zh-cn
    opkg install "$@"

    sed -i "/src\/gz openwrt_qbt file:\/\/${escaped_dir}/d" /etc/opkg/customfeeds.conf
    rm -f /etc/opkg/keys/527ca1333af7875e

    [ "$add_arch" != 1 ] || sed -i '/# qbt add start/{:a;N;/# qbt add end/!ba;d}' /etc/opkg.conf
}

remove_qbittorrent() {
    opkg --force-removal-of-dependent-packages remove "$@"
}

# ===================== HDSentinel =====================

deploy_hdsentinel() {
    local target="${1:-/root/HDSentinel}"
    local binary="${2:-HDSentinel-armv8}"

    if [ ! -f "$script_dir/$binary" ]; then
        echo "错误：未找到 $binary"
        echo "请将 HDSentinel-armv8 放入 $script_dir 目录"
        exit 1
    fi

    echo "正在部署 $binary → $target ..."
    cp -f "$script_dir/$binary" "$target"
    chmod +x "$target"
    echo "部署完成。运行: $target"
}

check_glibc_compat() {
    if [ -f "$script_dir/../../patches/glibc-compat-check.sh" ]; then
        sh "$script_dir/../../patches/glibc-compat-check.sh" "$@"
    else
        echo "错误：未找到 glibc-compat-check.sh" >&2
        exit 1
    fi
}

# ===================== 主入口 =====================

case "$1" in
    list)
        list_packages
        ;;
    install|remove)
        pkg_cmd="$1"; shift
        case "$pkg_cmd" in
            install) install_qbittorrent "$@" ;;
            remove)  remove_qbittorrent "$@" ;;
        esac
        ;;
    deploy-hdsentinel)
        shift
        deploy_hdsentinel "$@"
        ;;
    check-glibc)
        shift
        check_glibc_compat "$@"
        ;;
    *)
        echo "Usage: $0 [command] [args]"
        echo ""
        echo "Commands:"
        echo "  list                          List available IPK packages"
        echo "  install [pkgs...]             Install qbittorrent and related packages"
        echo "  remove <pkgs...>              Remove qbittorrent packages"
        echo "  deploy-hdsentinel [target]    Deploy HDSentinel binary to router"
        echo "  check-glibc [binary...]       Check glibc compatibility"
        echo ""
        ;;
esac
