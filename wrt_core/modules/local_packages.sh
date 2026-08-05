#!/usr/bin/env bash
# 本地源码包接入编译树。
#
# 用法：在 wrt_core/packages/ 下放置 OpenWrt 软件包源码（含 Makefile），
# install_local_packages 会在 feeds install 前将它们复制到 $BUILD_DIR/package/，
# 使 make defconfig / make 能够识别并编译这些本地包。

get_local_packages_dir() {
    printf '%s\n' "$BASE_PATH/packages"
}

install_local_packages() {
    local local_pkgs_dir
    local pkg_dir
    local pkg_name
    local count=0

    local_pkgs_dir=$(get_local_packages_dir)

    if [[ ! -d "$local_pkgs_dir" ]]; then
        echo "本地源码包目录不存在 ($local_pkgs_dir)，跳过。"
        return 0
    fi

    echo "正在接入本地源码包到编译树 (package/)..."
    for pkg_dir in "$local_pkgs_dir"/*/; do
        [[ -d "$pkg_dir" ]] || continue
        pkg_name=$(basename "$pkg_dir")
        if [[ ! -f "$pkg_dir/Makefile" ]]; then
            echo "  警告: $pkg_name 缺少 Makefile，跳过。"
            continue
        fi
        rm -rf "$BUILD_DIR/package/$pkg_name"
        cp -a "$pkg_dir" "$BUILD_DIR/package/$pkg_name"
        # rpcd 插件（root/usr/libexec/rpcd/*）必须可执行，否则 rpcd 无法加载、
        # LuCI 报 "Object not found"。复制到编译树后强制补执行位作为兜底
        # （项目仅 GitHub Actions/Linux 编译，检出时已按索引 100755 应用执行位）。
        if [[ -d "$BUILD_DIR/package/$pkg_name/root/usr/libexec/rpcd" ]]; then
            chmod +x "$BUILD_DIR/package/$pkg_name"/root/usr/libexec/rpcd/*
        fi
        echo "  [OK] $pkg_name → package/$pkg_name"
        count=$((count + 1))
    done

    if [[ $count -gt 0 ]]; then
        _mark_ok "local_packages" "${count} packages installed"
    else
        echo "本地源码包目录为空。"
    fi
}
