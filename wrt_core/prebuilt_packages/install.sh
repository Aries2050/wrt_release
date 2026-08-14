#!/bin/sh
# ⭐ 本地定制：管理预编译 IPK 包和 HDSentinel 部署
# 注意：全面转向 APK 后固件不再内置 opkg，本脚本的 opkg 安装仅适用于 opkg 固件；
# qbittorrent 后端已由构建期 install_prebuilt_ipks() 解压注入固件，一般无需本脚本。

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
    # APK 模式：固件已由构建期 install_prebuilt_ipks() 内置 qbittorrent 后端，
    # 不再通过 opkg 安装；如需手动安装请提供含 qbittorrent 的 APK 软件源。
    if command -v apk >/dev/null 2>&1; then
        echo "APK 模式：qBittorrent 后端已随固件内置（构建期注入），无需安装。"
        echo "如需手动安装，请使用: apk add qbittorrent（需配置含该包的 APK 源）"
        return 0
    fi
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

    # luci-app-qbittorrent 前端已改为源码编译（wrt_core/packages/），
    # 这里仅安装 qbittorrent 后端预编译包。
    # opkg 源已不再附带有效签名（索引变更后无法用私钥重签），
    # 故安装时使用 --no-check-signature 跳过校验。
    local escaped_dir=$(echo "$script_dir/pkgs" | sed 's/\//\\\//g')
    sed -i "\$asrc\/gz openwrt_qbt file:\/\/${escaped_dir}" /etc/opkg/customfeeds.conf 2>/dev/null

    mkdir -p /var/opkg-lists/
    cp "$script_dir/pkgs/Packages.gz" /var/opkg-lists/openwrt_qbt 2>/dev/null

    [ "$#" -gt 0 ] || set -- qbittorrent
    opkg --no-check-signature install "$@"

    sed -i "/src\/gz openwrt_qbt file:\/\/${escaped_dir}/d" /etc/opkg/customfeeds.conf

    [ "$add_arch" != 1 ] || sed -i '/# qbt add start/{:a;N;/# qbt add end/!ba;d}' /etc/opkg.conf
}

remove_qbittorrent() {
    # APK 模式：使用 apk 移除（若曾从 APK 源安装）
    if command -v apk >/dev/null 2>&1; then
        apk del "$@"
        return $?
    fi
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
        echo "  install [pkgs...]             Install qbittorrent backend (default: qbittorrent)"
        echo "  remove <pkgs...>              Remove qbittorrent packages"
        echo "  deploy-hdsentinel [target]    Deploy HDSentinel binary to router"
        echo "  check-glibc [binary...]       Check glibc compatibility"
        echo ""
        ;;
esac
