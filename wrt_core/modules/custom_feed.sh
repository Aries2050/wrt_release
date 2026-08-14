#!/usr/bin/env bash
# custom_feed 同步、注册和路径辅助。

# ⭐ 本地定制：构建访问 github.com 的认证参数（供自有仓库认证）。
# GitHub Actions 构建时注入 GITHUB_TOKEN；本地构建无 token 时返回空，回退本机 git 凭据。
build_github_auth_args() {
    local -n args_ref="$1"
    local b64
    args_ref=()
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        b64=$(printf '%s' "x-access-token:${GITHUB_TOKEN}" | base64 -w0 2>/dev/null || printf '%s' "x-access-token:${GITHUB_TOKEN}" | base64 | tr -d '\n')
        args_ref=(-c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${b64}")
    fi
}


get_custom_feed_name() {
    printf '%s\n' "custom_feed"
}


get_custom_feed_source_dir() {
    # install 前本地 src-link 的源目录。
    printf '%s\n' "$BUILD_DIR/$(get_custom_feed_name)"
}


get_custom_feed_worktree_dir() {
    # feeds update 后生成的 feeds/custom_feed 工作树。
    printf '%s\n' "$BUILD_DIR/feeds/$(get_custom_feed_name)"
}


get_custom_feed_package_dir() {
    # feeds install 后生成的 package/feeds/custom_feed 目录。
    printf '%s\n' "$BUILD_DIR/package/feeds/$(get_custom_feed_name)"
}


sync_sparse_packages_to_feed_dir() {
    local repo_url="$1"
    local repo_branch="$2"
    local target_dir="$3"
    local repo_label="$4"
    shift 4

    local packages=("$@")
    local tmp_dir
    local missing_packages=()
    local clone_args=()
    local auth_args=()
    local pkg

    build_github_auth_args auth_args
    clone_args=("${auth_args[@]}" clone --depth 1 --filter=blob:none --sparse)

    tmp_dir=$(mktemp -d)

    if [ -n "$repo_branch" ]; then
        clone_args+=(-b "$repo_branch")
    fi

    clone_args+=("$repo_url" "$tmp_dir")

    echo "正在从 $repo_label 稀疏同步指定目录..."
    if ! git_retry "${clone_args[@]}"; then
        echo "错误：从 $repo_url 拉取仓库骨架失败" >&2
        rm -rf "$tmp_dir"
        return 1
    fi

    if ! git_retry -C "$tmp_dir" sparse-checkout set "${packages[@]}"; then
        echo "错误：配置 $repo_label 稀疏检出目录失败" >&2
        rm -rf "$tmp_dir"
        return 1
    fi

    for pkg in "${packages[@]}"; do
        if [ -d "$tmp_dir/$pkg" ]; then
            rm -rf "$target_dir/$pkg"
            mv "$tmp_dir/$pkg" "$target_dir/"
        else
            missing_packages+=("$pkg")
        fi
    done

    rm -rf "$tmp_dir"

    if [ ${#missing_packages[@]} -ne 0 ]; then
        printf '错误：%s 仓库缺少以下必要目录：\n' "$repo_label" >&2
        printf '  - %s\n' "${missing_packages[@]}" >&2
        return 1
    fi
}


sync_repo_root_package_to_feed_dir() {
    local repo_url="$1"
    local repo_branch="$2"
    local target_dir="$3"
    local repo_label="$4"
    local package_name="$5"
    local tmp_dir
    local clone_args=()
    local auth_args=()

    build_github_auth_args auth_args
    clone_args=("${auth_args[@]}" clone --depth 1 --filter=blob:none)

    tmp_dir=$(mktemp -d)

    if [ -n "$repo_branch" ]; then
        clone_args+=(-b "$repo_branch")
    fi

    clone_args+=("$repo_url" "$tmp_dir")

    echo "正在从 $repo_label 同步单包仓库..."
    if ! git_retry "${clone_args[@]}"; then
        echo "错误：从 $repo_url 克隆 $repo_label 失败" >&2
        rm -rf "$tmp_dir"
        return 1
    fi

    if [ ! -f "$tmp_dir/Makefile" ]; then
        echo "错误：$repo_label 仓库根目录缺少 OpenWrt 软件包 Makefile" >&2
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$tmp_dir/.git"
    rm -rf "$target_dir/$package_name"

    if ! mv "$tmp_dir" "$target_dir/$package_name"; then
        echo "错误：无法将 $repo_label 移动到 $target_dir/$package_name" >&2
        rm -rf "$tmp_dir"
        return 1
    fi
}


fix_emmc_health_luci_js_deps() {
    local package_dir="$1"
    local makefile_path="$package_dir/Makefile"

    if [ ! -f "$makefile_path" ]; then
        echo "错误：luci-app-emmc-health Makefile 不存在：$makefile_path" >&2
        return 1
    fi

    if grep -q "luci-js-deps" "$makefile_path"; then
        sed -i '/^[[:space:]]*DEPENDS:=/ s/[[:space:]]*+luci-js-deps//g' "$makefile_path"
        echo "已移除 luci-app-emmc-health 的 luci-js-deps 兼容性依赖。"
    fi
}


# ⭐ 本地定制：luci-app-tailscale 与 tailscale 二进制核心包文件冲突处理。
# kenzok8/small-package 的 luci-app-tailscale 自带 /etc/init.d/tailscale 与
# /etc/config/tailscale，与同源 tailscale 二进制包（同样安装这两路径）在 apk/opkg
# 严格文件 ownership 检查下冲突 → 移除这两个静态文件（由二进制包提供）；
# 但二进制包 config 缺失 luci-app 界面/hotplug 依赖的字段（enabled 等），
# 故在 uci-defaults 首次开机时幂等补充（存在则跳过，不覆盖用户值）。
fix_luci_app_tailscale_conflict() {
    local package_dir="$1"
    local uci_defaults_path="$package_dir/root/etc/uci-defaults/40_luci-tailscale"

    rm -f "$package_dir/root/etc/config/tailscale"
    rm -f "$package_dir/root/etc/init.d/tailscale"

    if [ -f "$uci_defaults_path" ]; then
        grep -q "tailscale.settings.enabled" "$uci_defaults_path" && return 0
        sed -i '/^exit 0$/i\
# ⭐ 本地定制：补充二进制包 config 缺失的 luci-app 界面/hotplug 依赖字段（幂等）\
if ! uci -q get tailscale.settings.enabled >/dev/null 2>&1; then\
    uci -q set tailscale.settings.enabled=0\
    uci -q set tailscale.settings.config_path=/etc/tailscale\
    uci -q set tailscale.settings.accept_dns=1\
    uci -q commit tailscale\
fi\
' "$uci_defaults_path"
        echo "已处理 luci-app-tailscale 与 tailscale 二进制包的文件冲突（移除静态 config/init，uci-defaults 幂等补充字段）。"
    fi
}


register_local_feed_source() {
    local custom_feed_dir="$1"
    local feeds_path="$2"
    local feed_name
    feed_name=$(get_custom_feed_name)

    sed -i "/[[:space:]]$feed_name[[:space:]]/d" "$feeds_path"
    [ -z "$(tail -c 1 "$feeds_path")" ] || echo "" >>"$feeds_path"
    echo "src-link $feed_name $custom_feed_dir" >>"$feeds_path"
    echo "已将 $feed_name 作为本地源 (src-link) 添加到 $feeds_path"
}


install_custom_feed() {
    local feeds_path
    local fullconenat_nft_dir="$BUILD_DIR/package/network/utils/fullconenat-nft"
    local fullconenat_dir="$BUILD_DIR/package/network/utils/fullconenat"
    local custom_feed_dir
    local custom_feed_worktree_dir
    local custom_feed_name

    local base_custom_feed_packages=(
        xray-core xray-plugin dns2tcp dns2socks haproxy hysteria \
        naiveproxy shadowsocks-rust sing-box v2ray-core v2ray-geodata geoview v2ray-plugin \
        tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev \
        v2dat adguardhome ddns-go \
        luci-app-ddns-go taskd luci-lib-xterm luci-lib-taskd luci-app-store quickstart \
        luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest netdata luci-app-netdata \
        lucky luci-app-lucky luci-app-openclash luci-app-homeproxy luci-app-amlogic \
        oaf open-app-filter luci-app-oaf easytier luci-app-easytier \
        msd_lite luci-app-msd_lite cups luci-app-cupsd \
        tailscale luci-app-tailscale
    )
    local required_feed_dirs=(
        cups tcping v2ray-geodata luci-lib-taskd luci-app-openclash
        luci-app-quickstart luci-app-store luci-app-homeproxy luci-app-mosdns
        luci-app-passwall nikki luci-app-nikki mihomo-meta
        open-app-filter luci-app-oaf lucky luci-app-lucky luci-app-easytier
        luci-app-emmc-health luci-app-adguardhome
    )
    local custom_feed_sources=()
    local missing_feed_dirs=()
    local source_entry
    local repo_label
    local repo_url
    local repo_branch
    local repo_packages
    local repo_package_array=()

    if [ ! -d "$fullconenat_nft_dir" ]; then
        base_custom_feed_packages+=(fullconenat-nft)
    fi
    if [ ! -d "$fullconenat_dir" ]; then
        base_custom_feed_packages+=(fullconenat)
    fi

    # 统一从外部仓库同步指定包，避免分散维护 feeds.conf。
    custom_feed_sources=(
        "kenzok8/small-package|https://github.com/kenzok8/small-package.git||${base_custom_feed_packages[*]}"
        "sbwml/luci-app-mosdns|https://github.com/sbwml/luci-app-mosdns.git|v5|mosdns luci-app-mosdns"
        "Openwrt-Passwall/openwrt-passwall|https://github.com/Openwrt-Passwall/openwrt-passwall.git|main|luci-app-passwall"
        "nikkinikki-org/OpenWrt-nikki|https://github.com/nikkinikki-org/OpenWrt-nikki.git|main|nikki luci-app-nikki mihomo-meta"
    )

    feeds_path=$(get_feeds_path)
    custom_feed_name=$(get_custom_feed_name)
    custom_feed_dir=$(get_custom_feed_source_dir)
    custom_feed_worktree_dir=$(get_custom_feed_worktree_dir)

    if [ -d "$custom_feed_dir" ]; then
        echo "清理旧的自定义 feed 目录..."
        rm -rf "$custom_feed_dir"
    fi
    mkdir -p "$custom_feed_dir"

    for source_entry in "${custom_feed_sources[@]}"; do
        IFS='|' read -r repo_label repo_url repo_branch repo_packages <<< "$source_entry"
        read -r -a repo_package_array <<< "$repo_packages"

        if ! sync_sparse_packages_to_feed_dir "$repo_url" "$repo_branch" "$custom_feed_dir" "$repo_label" "${repo_package_array[@]}"; then
            rm -rf "$custom_feed_dir"
            return 1
        fi
    done

    # ⭐ 本地定制：luci-app-adguardhome 改用自有仓库 Aries2050/luci-app-adguardhome 版本
    # （覆盖上面 kenzok8/small-package 中的同名包；有 GITHUB_TOKEN 时自动认证，无则用本机 git 凭据）
    # 2026-08-13：仓库已重构为单包仓库（根目录 Makefile），改用整仓同步。
    if ! sync_repo_root_package_to_feed_dir \
        "https://github.com/Aries2050/luci-app-adguardhome.git" \
        "master" "$custom_feed_dir" "Aries2050/luci-app-adguardhome" "luci-app-adguardhome"; then
        rm -rf "$custom_feed_dir"
        return 1
    fi

    # ⭐ 本地定制：luci-app-tailscale 与 tailscale 二进制包文件冲突处理（APK 严格 ownership 检查）
    if [ -d "$custom_feed_dir/luci-app-tailscale" ]; then
        if ! fix_luci_app_tailscale_conflict "$custom_feed_dir/luci-app-tailscale"; then
            rm -rf "$custom_feed_dir"
            return 1
        fi
    fi

    # ⭐ 本地定制：rpcd 插件必须可执行（100755），否则 rpcd 无法加载、LuCI 报 "Object not found"。
    # 源头已修复为 100755（2026-08-13）；此处保留幂等兑底（与 local_packages.sh 处理一致）。
    if [ -d "$custom_feed_dir/luci-app-adguardhome/root/usr/libexec/rpcd" ]; then
        chmod +x "$custom_feed_dir/luci-app-adguardhome"/root/usr/libexec/rpcd/*
    fi

    if ! sync_repo_root_package_to_feed_dir "https://github.com/adminchenyu/eMMC-Health.git" "main" "$custom_feed_dir" "adminchenyu/eMMC-Health" "luci-app-emmc-health"; then
        rm -rf "$custom_feed_dir"
        return 1
    fi

    if ! fix_emmc_health_luci_js_deps "$custom_feed_dir/luci-app-emmc-health"; then
        rm -rf "$custom_feed_dir"
        return 1
    fi

    register_local_feed_source "$custom_feed_dir" "$feeds_path"

    echo "正在更新 $custom_feed_name 本地 feed 索引..."
    network_retry ./scripts/feeds update "$custom_feed_name"

    collect_missing_directories "$custom_feed_worktree_dir" required_feed_dirs missing_feed_dirs

    if [ ${#missing_feed_dirs[@]} -ne 0 ]; then
        printf '错误：%s 本地 feed 未生成以下仓库依赖路径：\n' "$custom_feed_name" >&2
        printf '  - %s\n' "${missing_feed_dirs[@]}" >&2
        return 1
    fi

    echo "$custom_feed_name 指定包处理完成并已成功加载到 feeds 体系中！"
}


collect_missing_directories() {
    local base_dir="$1"
    local -n required_dirs_ref="$2"
    local -n missing_dirs_ref="$3"
    local dir_name

    for dir_name in "${required_dirs_ref[@]}"; do
        if [ ! -d "$base_dir/$dir_name" ]; then
            missing_dirs_ref+=("${base_dir#$BUILD_DIR/}/$dir_name")
        fi
    done
}
