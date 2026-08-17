#!/usr/bin/env bash
# target、kernel 与 base system 源码修正。

# ═══════════════════════════════════════════════════════════
# 构建标记系统：各定制步骤写入 $BUILD_DIR/.build_marks/，
# CI 通过读取标记替代 grep/find 猜测，实现"主动上报"。
# ═══════════════════════════════════════════════════════════
BUILD_MARKS_DIR="${BUILD_DIR}/.build_marks"

_mark_init() {
    mkdir -p "$BUILD_MARKS_DIR"
}

# _mark_ok <name> [detail]
_mark_ok() {
    local name="$1" detail="${2:-}"
    _mark_init
    if [ -n "$detail" ]; then
        echo "ok ${detail}" > "$BUILD_MARKS_DIR/${name}"
    else
        echo "ok" > "$BUILD_MARKS_DIR/${name}"
    fi
}

# _mark_fail <name> <reason>
_mark_fail() {
    local name="$1" reason="$2"
    _mark_init
    echo "fail ${reason}" > "$BUILD_MARKS_DIR/${name}"
}

fix_default_set() {
    # 注入默认主题、系统设置和目标平台通用补丁。
    if [ -d "$BUILD_DIR/feeds/luci/collections/" ]; then
        find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$THEME_SET/g" {} \;
    fi

    local mark_uci=0
    install -Dm544 "$BASE_PATH/patches/990_set_argon_primary" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/990_set_argon_primary" && { ((++mark_uci)); _mark_ok "file_990_argon"; } || _mark_fail "file_990_argon" "install failed"
    install -Dm544 "$BASE_PATH/patches/991_custom_settings" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/991_custom_settings" && { ((++mark_uci)); _mark_ok "file_991_settings"; } || _mark_fail "file_991_settings" "install failed"
    install -Dm544 "$BASE_PATH/patches/992_set-wifi-uci.sh" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/992_set-wifi-uci.sh" && { ((++mark_uci)); _mark_ok "file_992_wifi"; } || _mark_fail "file_992_wifi" "install failed"
    install -Dm544 "$BASE_PATH/patches/993_run-custom-boot-scripts" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/993_run-custom-boot-scripts" && { ((++mark_uci)); _mark_ok "file_993_custom_boot"; } || _mark_fail "file_993_custom_boot" "install failed"
    install -Dm544 "$BASE_PATH/patches/995_disable_unused_services" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/995_disable_unused_services" && { ((++mark_uci)); _mark_ok "file_995_disable_services"; } || _mark_fail "file_995_disable_services" "install failed"
    _mark_ok "uci_defaults" "${mark_uci}/5 files"

    if [ -f "$BUILD_DIR/package/emortal/autocore/files/tempinfo" ]; then
        if [ -f "$BASE_PATH/patches/tempinfo" ]; then
            \cp -f "$BASE_PATH/patches/tempinfo" "$BUILD_DIR/package/emortal/autocore/files/tempinfo"
        fi
    fi
}


fix_miniupnpd() {
    local miniupnpd_dir="$BUILD_DIR/feeds/packages/net/miniupnpd"
    local patch_file="999-chanage-default-leaseduration.patch"

    if [ -d "$miniupnpd_dir" ] && [ -f "$BASE_PATH/patches/$patch_file" ]; then
        install -Dm644 "$BASE_PATH/patches/$patch_file" "$miniupnpd_dir/patches/$patch_file" && \
            _mark_ok "patch_miniupnpd" || _mark_fail "patch_miniupnpd" "install failed"
    fi
}


change_dnsmasq2full() {
    if ! grep -q "dnsmasq-full" $BUILD_DIR/include/target.mk; then
        sed -i 's/dnsmasq/dnsmasq-full/g' ./include/target.mk
        _mark_ok "dnsmasq_full" "switched"
    else
        _mark_ok "dnsmasq_full" "already set"
    fi
}


fix_mk_def_depends() {
    sed -i 's/libustream-mbedtls/libustream-openssl/g' $BUILD_DIR/include/target.mk 2>/dev/null
    if [ -f $BUILD_DIR/target/linux/qualcommax/Makefile ]; then
        sed -i 's/wpad-openssl/wpad-mesh-openssl/g' $BUILD_DIR/target/linux/qualcommax/Makefile
    fi
}


fix_kconfig_recursive_dependency() {
    local file="$BUILD_DIR/scripts/package-metadata.pl"
    if [ -f "$file" ]; then
        sed -i 's/<PACKAGE_\$pkgname/!=y/g' "$file"
        echo "已修复 package-metadata.pl 的 Kconfig 递归依赖生成逻辑。"
    fi
}


update_default_lan_addr() {
    local CFG_PATH="$BUILD_DIR/package/base-files/files/bin/config_generate"
    if [ -f $CFG_PATH ]; then
        sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$LAN_ADDR'/g' $CFG_PATH
        _mark_ok "lan_addr" "${LAN_ADDR}"
    else
        _mark_fail "lan_addr" "config_generate not found"
    fi
}


remove_something_nss_kmod() {
    local ipq_mk_path="$BUILD_DIR/target/linux/qualcommax/Makefile"
    local target_mks=("$BUILD_DIR/target/linux/qualcommax/ipq60xx/target.mk" "$BUILD_DIR/target/linux/qualcommax/ipq807x/target.mk")

    for target_mk in "${target_mks[@]}"; do
        if [ -f "$target_mk" ]; then
            sed -i 's/kmod-qca-nss-crypto//g' "$target_mk"
        fi
    done

    if [ -f "$ipq_mk_path" ]; then
        sed -i '/kmod-qca-nss-drv-eogremgr/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-gre/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-map-t/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-match/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-mirror/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-tun6rd/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-tunipip6/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-vxlanmgr/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-wifi-meshmgr/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-macsec/d' "$ipq_mk_path"

        sed -i 's/automount //g' "$ipq_mk_path"
        sed -i 's/cpufreq //g' "$ipq_mk_path"
    fi
}


update_affinity_script() {
    local affinity_script_dir="$BUILD_DIR/target/linux/qualcommax"

    if [ -d "$affinity_script_dir" ]; then
        find "$affinity_script_dir" -name "set-irq-affinity" -exec rm -f {} \;
        find "$affinity_script_dir" -name "smp_affinity" -exec rm -f {} \;
        install -Dm755 "$BASE_PATH/patches/smp_affinity" "$affinity_script_dir/base-files/etc/init.d/smp_affinity" && \
            _mark_ok "script_smp_affinity" || _mark_fail "script_smp_affinity" "install failed"
    fi
}


fix_nn6000_led_label() {
    # 修正 NN6000 DTS 中 GPIO 极性标志，使其匹配低电平有效（ACTIVE_LOW）的 LED 硬件。
    #
    # 经 2026-07-19 在原厂固件和 ImmortalWRT 上交叉验证确认:
    #   GPIO 50 → 🔴 红 (status-red)
    #   GPIO 70 → 🟢 绿 (status-green)
    #   GPIO 69 → 🔵 蓝 (status-blue)
    #
    # 真实问题: ImmortalWRT DTS 中 gpios 的 flags 为 GPIO_ACTIVE_HIGH (0x00)，
    # 但硬件为低电平有效（common anode），应使用 GPIO_ACTIVE_LOW (0x01)。
    #
    # 修复: 搜索以下位置，找到包含 status-red 的文件，将其 gpios flags
    #       从 GPIO_ACTIVE_HIGH (0) 改为 GPIO_ACTIVE_LOW (1)，并添加 active-low;
    #   - target/linux/qualcommax/patches-[0-9]*/  (内核补丁，NN6000 DTS 通常在此)
    #   - target/linux/qualcommax/dts/              (原始 DTS 目录)
    #   - target/linux/qualcommax/files-[0-9]*/     (内核覆层目录)
    #
    # DTS 格式示例:
    #   修复前: gpios = <&tlmm 50 GPIO_ACTIVE_HIGH>;
    #   修复后: gpios = <&tlmm 50 GPIO_ACTIVE_LOW>;
    #           active-low;

    local fixed=0
    local search_dirs=()
    local found_files=()

    # 构建搜索目录列表（按优先级）
    # 1. patches-[0-9]* 目录 — NN6000 DTS 常以内核补丁形式存在
    local patch_dir
    patch_dir=$(find "$BUILD_DIR/target/linux/qualcommax" -maxdepth 1 -type d -name "patches-[0-9]*" 2>/dev/null | head -1)
    [ -n "$patch_dir" ] && search_dirs+=("$patch_dir")

    # 2. files-[0-9]* 内核覆层目录
    local files_dir
    files_dir=$(find "$BUILD_DIR/target/linux/qualcommax" -maxdepth 1 -type d -name "files-[0-9]*" 2>/dev/null | head -1)
    [ -n "$files_dir" ] && search_dirs+=("$files_dir")

    # 3. dts/ 目录
    [ -d "$BUILD_DIR/target/linux/qualcommax/dts" ] && search_dirs+=("$BUILD_DIR/target/linux/qualcommax/dts")

    if [ ${#search_dirs[@]} -eq 0 ]; then
        echo "警告: 未找到 Qualcommax DTS/patches 目录，跳过 LED GPIO 极性修正" >&2
        return
    fi

    # 在所有搜索目录中找包含 status-red 的文件
    for dir in "${search_dirs[@]}"; do
        while read -r file; do
            found_files+=("$file")
        done < <(grep -rli "status-red" "$dir" --include="*.dts" --include="*.dtsi" --include="*.patch" 2>/dev/null || true)
    done

    # 过滤：仅保留 Link/NN6000 设备文件，避免误伤其他 IPQ60xx 设备
    # （如 ipq6010-philips.dtsi 也有 status-red 但 GPIO 映射完全不同）
    local filtered_files=()
    local f
    for f in "${found_files[@]}"; do
        case "$(basename "$f")" in
            *link*|*nn6000*|*NN6000*|*LINK*|*Link*)
                filtered_files+=("$f")
                ;;
            *)
                echo "  ⏭ 跳过非 NN6000/Link 文件: $(echo "$f" | sed "s|$BUILD_DIR/||")"
                ;;
        esac
    done
    found_files=("${filtered_files[@]}")

    if [ ${#found_files[@]} -eq 0 ]; then
        echo "警告: 未找到 NN6000/Link 的 DTS/补丁文件（含 status-red），跳过 LED GPIO 极性修正" >&2
        return
    fi

    # 去重
    local unique_files=()
    local f
    for f in "${found_files[@]}"; do
        local already=0
        local u
        for u in "${unique_files[@]}"; do
            [ "$u" = "$f" ] && { already=1; break; }
        done
        [ "$already" -eq 0 ] && unique_files+=("$f")
    done

    echo "发现 ${#unique_files[@]} 个含 status-red 的文件:"
    for f in "${unique_files[@]}"; do
        echo "  → $(echo "$f" | sed "s|$BUILD_DIR/||")"
    done

    # 在每个文件中修正三个 LED 节点的 GPIO 极性
    for dts_file in "${unique_files[@]}"; do
        for node in status-red status-green status-blue; do
            if grep -q "$node" "$dts_file"; then
                # Step 1: GPIO_ACTIVE_HIGH → GPIO_ACTIVE_LOW（对 raw DTS 和 .patch 都有效）
                sed -i "/$node {/,/};/{
                    /gpios =/s/GPIO_ACTIVE_HIGH/GPIO_ACTIVE_LOW/g
                }" "$dts_file"

                # Step 2: 添加 active-low; 属性（兼容 raw DTS 和 .patch 两种格式）
                #   .patch 文件行前缀为 "+"，需保留前缀；raw DTS 无前缀
                sed -i "/$node {/,/};/{
                    /active-low;/!{
                        /^[+]/ s/\(+\)\(.*$node {\)/\1\2\n\1\t\tactive-low;/
                        /^[^+]/ s/\($node {\)/\1\n\t\tactive-low;/
                    }
                }" "$dts_file"

                echo "  ✅ 已修正 $node: GPIO_ACTIVE_HIGH → ACTIVE_LOW, +active-low;"
                fixed=1
            fi
        done
    done

    if [ "$fixed" -eq 1 ]; then
        echo "完成: NN6000 LED GPIO 极性已从 ACTIVE_HIGH 修正为 ACTIVE_LOW（共 ${#unique_files[@]} 个文件）"
        _mark_ok "dts_nn6000_led" "${#unique_files[@]} files, $(grep -c 'active-low;' "${unique_files[@]}" 2>/dev/null || echo 0) active-low props"
    else
        echo "警告: 未找到需要修正的 LED 节点" >&2
        _mark_fail "dts_nn6000_led" "no status-red nodes found in Link/NN6000 DTS"
    fi
}


fix_hash_value() {
    local makefile_path="$1"
    local old_hash="$2"
    local new_hash="$3"
    local package_name="$4"

    if [ -f "$makefile_path" ]; then
        sed -i "s/$old_hash/$new_hash/g" "$makefile_path"
        echo "已修正 $package_name 的哈希值。"
    fi
}


apply_hash_fixes() {
    fix_hash_value \
        "$BUILD_DIR/package/feeds/packages/smartdns/Makefile" \
        "860a816bf1e69d5a8a2049483197dbebe8a3da2c9b05b2da68c85ef7dee7bdde" \
        "582021891808442b01f551bc41d7d95c38fb00c1ec78a58ac3aaaf898fbd2b5b" \
        "smartdns"

    fix_hash_value \
        "$BUILD_DIR/package/feeds/packages/smartdns/Makefile" \
        "320c99a65ca67a98d11a45292aa99b8904b5ebae5b0e17b302932076bf62b1ec" \
        "43e58467690476a77ce644f9dc246e8a481353160644203a1bd01eb09c881275" \
        "smartdns"
}


update_ath11k_fw() {
    local makefile="$BUILD_DIR/package/firmware/ath11k-firmware/Makefile"
    local new_mk="$BASE_PATH/patches/ath11k_fw.mk"
    local url="https://raw.githubusercontent.com/VIKINGYFY/immortalwrt/refs/heads/main/package/firmware/ath11k-firmware/Makefile"
    local ipq60_target="$BUILD_DIR/target/linux/qualcommax/ipq60xx/target.mk"
    local ipq807_target="$BUILD_DIR/target/linux/qualcommax/ipq807x/target.mk"

    if [ -d "$(dirname "$makefile")" ]; then
        echo "正在更新 ath11k-firmware Makefile..."
        if ! curl_retry -fsSL -o "$new_mk" "$url"; then
            echo "错误：从 $url 下载 ath11k-firmware Makefile 失败" >&2
            exit 1
        fi
        if [ ! -s "$new_mk" ]; then
            echo "错误：下载的 ath11k-firmware Makefile 为空文件" >&2
            exit 1
        fi
        mv -f "$new_mk" "$makefile"

        if [ -f "$ipq60_target" ]; then
            sed -i 's/ath11k-firmware-ipq6018\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq6018-ddwrt\1/g' "$ipq60_target"
        fi

        if [ -f "$ipq807_target" ]; then
            sed -i 's/ath11k-firmware-ipq8074\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq8074-ddwrt\1/g' "$ipq807_target"
        fi

        if [ -f "$ipq60_target" ] || [ -f "$ipq807_target" ]; then
            echo "已同步 ipq60xx/ipq807x ath11k 固件依赖为 ddwrt 包名。"
            _mark_ok "ath11k_fw" "ddwrt synced"
        fi
    fi
}


change_cpuusage() {
    local luci_rpc_path="$BUILD_DIR/feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci"
    local qualcommax_sbin_dir="$BUILD_DIR/target/linux/qualcommax/base-files/sbin"
    local filogic_sbin_dir="$BUILD_DIR/target/linux/mediatek/filogic/base-files/sbin"

    if [ -f "$luci_rpc_path" ]; then
        sed -i "s#const fd = popen('top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\'')#const cpuUsageCommand = access('/sbin/cpuusage') ? '/sbin/cpuusage' : 'top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\''#g" "$luci_rpc_path"
        sed -i '/cpuUsageCommand/a \\t\t\tconst fd = popen(cpuUsageCommand);' "$luci_rpc_path"
    fi

    local old_script_path="$BUILD_DIR/package/base-files/files/sbin/cpuusage"
    if [ -f "$old_script_path" ]; then
        rm -f "$old_script_path"
    fi

    if [ -d "$BUILD_DIR/target/linux/qualcommax" ]; then
        install -Dm755 "$BASE_PATH/patches/cpuusage" "$qualcommax_sbin_dir/cpuusage" && \
            _mark_ok "script_cpuusage" "qualcommax" || _mark_fail "script_cpuusage" "install failed"
    fi
    if [ -d "$BUILD_DIR/target/linux/mediatek" ]; then
        install -Dm755 "$BASE_PATH/patches/hnatusage" "$filogic_sbin_dir/cpuusage" && \
            _mark_ok "script_cpuusage" "hnatusage" || _mark_fail "script_cpuusage" "hnatusage install failed"
    fi
}


update_nss_pbuf_performance() {
    local pbuf_path="$BUILD_DIR/package/kernel/mac80211/files/pbuf.uci"
    if [ -d "$(dirname "$pbuf_path")" ] && [ -f $pbuf_path ]; then
        sed -i "s/auto_scale '1'/auto_scale 'off'/g" $pbuf_path
        sed -i "s/scaling_governor 'performance'/scaling_governor 'schedutil'/g" $pbuf_path
    fi
}


update_nss_diag() {
    local file="$BUILD_DIR/package/kernel/mac80211/files/nss_diag.sh"
    if [ -d "$(dirname "$file")" ] && [ -f "$file" ]; then
        \rm -f "$file"
        install -Dm755 "$BASE_PATH/patches/nss_diag.sh" "$file" && \
            _mark_ok "script_nss_diag" || _mark_fail "script_nss_diag" "install failed"
    fi
}


fix_compile_coremark() {
    local file="$BUILD_DIR/feeds/packages/utils/coremark/Makefile"
    if [ -d "$(dirname "$file")" ] && [ -f "$file" ]; then
        sed -i 's/mkdir \$/mkdir -p \$/g' "$file"
    fi
}


update_dnsmasq_conf() {
    local file="$BUILD_DIR/package/network/services/dnsmasq/files/dhcp.conf"
    if [ -d "$(dirname "$file")" ] && [ -f "$file" ]; then
        sed -i '/dns_redirect/d' "$file"
    fi
}


add_backup_info_to_sysupgrade() {
    local conf_path="$BUILD_DIR/package/base-files/files/etc/sysupgrade.conf"

    if [ -f "$conf_path" ]; then
        cat >>"$conf_path" <<'EOF'
/etc/AdGuardHome.yaml
/etc/easytier
/etc/lucky/
/etc/custom-boot.d/
EOF
        _mark_ok "sysupgrade_backup" "4 paths added"
    else
        _mark_fail "sysupgrade_backup" "sysupgrade.conf not found"
    fi
}


fix_rust_compile_error() {
    if [ -f "$BUILD_DIR/feeds/packages/lang/rust/Makefile" ]; then
        sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' "$BUILD_DIR/feeds/packages/lang/rust/Makefile"
    fi
}


update_hdsentinel() {
    local hds_arch="armv8"
    local hds_url="https://www.hdsentinel.com/hdslin/hdsentinel-armv8.zip"
    local hds_zip="hdsentinel-armv8.zip"
    local hds_dest="$BUILD_DIR/files/bin/HDSentinel"
    local tmp_dir="${TMPDIR:-/tmp}/hdsentinel-$$"
    local local_zip="$BASE_PATH/prebuilt_packages/hdsentinel"

    # 检测目标架构，选择正确的 HDSentinel 版本
    if [[ -n "$DEV_NAME" ]]; then
        local dev_config="$BASE_PATH/deconfig/$DEV_NAME.config"
        if [[ -f "$dev_config" ]] && grep -q "CONFIG_TARGET_x86_64=y" "$dev_config" 2>/dev/null; then
            hds_arch="x64"
            hds_url="https://www.hdsentinel.com/hdslin/hdsentinel-020c-x64.zip"
            hds_zip="hdsentinel-020c-x64.zip"
        fi
    fi

    echo "正在下载 HDSentinel (${hds_arch})..."
    mkdir -p "$tmp_dir"

    # 阶段 1：尝试网络下载
    local use_local=0
    local fail_reason=""
    if ! wget_retry -q "$hds_url" -O "$tmp_dir/$hds_zip"; then
        echo "警告：下载 HDSentinel (${hds_arch}) 失败，尝试本地副本..." >&2
        use_local=1
        fail_reason="wget failed"
    fi

    # 阶段 2：验证文件有效性（大小 + zip 格式）
    if [[ "$use_local" -eq 0 ]]; then
        local dl_size
        dl_size=$(stat -c%s "$tmp_dir/$hds_zip" 2>/dev/null || echo 0)
        if [[ "$dl_size" -lt 524288 ]]; then
            echo "警告：下载的 HDSentinel 过小 (${dl_size} bytes)，转用本地副本..." >&2
            use_local=1
            fail_reason="too small (${dl_size} bytes)"
        elif ! unzip -tq "$tmp_dir/$hds_zip" 2>/dev/null; then
            echo "警告：下载的 HDSentinel 不是有效 zip，转用本地副本..." >&2
            use_local=1
            fail_reason="invalid zip"
        fi
    fi

    # 阶段 3：本地副本回退（统一入口）
    if [[ "$use_local" -eq 1 ]]; then
        if [[ -f "$local_zip/$hds_zip" ]]; then
            echo "使用本地副本: $local_zip/$hds_zip"
            \cp -f "$local_zip/$hds_zip" "$tmp_dir/$hds_zip"
            _mark_ok "hdsentinel" "fallback to local copy (${fail_reason})"
        else
            echo "警告：本地副本也不存在 ($local_zip/$hds_zip)，跳过 HDSentinel 集成" >&2
            _mark_fail "hdsentinel" "no local backup (${fail_reason})"
            rm -rf "$tmp_dir"
            return 0
        fi
    fi

    if ! unzip -q -o "$tmp_dir/$hds_zip" -d "$tmp_dir"; then
        echo "警告：解压 HDSentinel 失败，跳过 HDSentinel 集成" >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    local extracted
    extracted=$(find "$tmp_dir" -maxdepth 1 -type f -executable -o -name "HDSentinel" -o -name "hdsentinel" 2>/dev/null | head -1)
    if [[ -z "$extracted" ]]; then
        # 尝试查找任何非目录、非 zip 的文件
        extracted=$(find "$tmp_dir" -maxdepth 1 -type f ! -name "*.zip" | head -1)
    fi

    if [[ -n "$extracted" ]]; then
        install -Dm755 "$extracted" "$hds_dest"
        echo "HDSentinel 已安装到 $hds_dest"

        # ⭐ 创建全局包装脚本：输入 hdsentinel 即可直接调用（内部自动通过 glibc-run 加载）
        local wrapper_path="$BUILD_DIR/files/usr/bin/hdsentinel"
        mkdir -p "$(dirname "$wrapper_path")"
        cat > "$wrapper_path" << 'HDSEOF'
#!/bin/sh
# ⭐ HDSentinel 全局包装脚本：自动通过 glibc-run 加载 glibc 二进制
exec glibc-run /bin/HDSentinel "$@"
HDSEOF
        chmod +x "$wrapper_path"
        echo "全局包装脚本已创建: $wrapper_path（终端输入 hdsentinel 即可使用）"

        # ⭐ 设置 HDSENTINEL 全局环境变量，供脚本检测
        local profile_d="$BUILD_DIR/files/etc/profile.d"
        mkdir -p "$profile_d"
        cat > "$profile_d/hdsentinel.sh" << 'ENVEOF'
# ⭐ HDSentinel 环境变量
export HDSENTINEL="/bin/HDSentinel"
ENVEOF
        chmod +x "$profile_d/hdsentinel.sh"
        echo "环境变量已设置: HDSENTINEL=/bin/HDSentinel"
        _mark_ok "hdsentinel" "installed ${hds_arch} $(stat -c%s "$hds_dest") bytes"
    else
        echo "警告：未找到解压后的 HDSentinel 二进制文件，跳过 HDSentinel 集成" >&2
        ls -la "$tmp_dir"
        _mark_fail "hdsentinel" "binary not found after unzip"
        rm -rf "$tmp_dir"
        return 0
    fi

    rm -rf "$tmp_dir"
    _mark_ok "hdsentinel" "installed ${hds_arch}" 2>/dev/null || true  # 兜底：如果上面没写标记
}


# ⭐ 将预编译 IPK 注入固件根文件系统（解压到 BUILD_DIR/files/）
# 用于在固件中预装 qBittorrent 后端等无法通过源码编译的包。
# 注意：luci-app-qbittorrent 前端已改为本地源码编译（wrt_core/packages/），
#       不再通过预编译 IPK 注入。
install_prebuilt_ipks() {
    local pkg_dir="$BASE_PATH/prebuilt_packages/pkgs"
    local target_dir="$BUILD_DIR/files"
    local count=0

    if [[ ! -d "$pkg_dir" ]]; then
        echo "警告：预编译包目录不存在 ($pkg_dir)" >&2
        return 0
    fi

    local ipk_files=(
        "$pkg_dir/qbittorrent_"*.ipk
    )

    echo "正在注入预编译 IPK 到固件..."
    for ipk in "${ipk_files[@]}"; do
        [[ -f "$ipk" ]] || continue
        local name
        name=$(basename "$ipk")
        echo "  [${name}] 解压中..."

        local tmp_dir
        tmp_dir=$(mktemp -d)

        # 解压 .ipk — 标准格式为 ar 归档，但部分 IPK 为 gzip 包裹的 tar 归档
        # 策略：优先 7zz/7z 直接提取；若未得到 debian-binary 则尝试管道二次提取
        local extracted=0
        if command -v 7zz &>/dev/null; then
            (cd "$tmp_dir" && 7zz x "$ipk" -y -bso0 -bsp0) 2>/dev/null
            extracted=1
        elif command -v 7z &>/dev/null; then
            (cd "$tmp_dir" && 7z x "$ipk" -y -bso0 -bsp0) 2>/dev/null
            extracted=1
        else
            echo "  警告: 无法解压 ${name}（7zz/7z 均不可用）" >&2
            rm -rf "$tmp_dir"
            continue
        fi

        # 若直接解压未产生 debian-binary，说明可能是 gzip+tarball 格式
        # 此时 7zz/7z 只解了 gzip 层，还需提取内层 tar
        if [ ! -f "$tmp_dir/debian-binary" ] && [ "$extracted" -eq 1 ]; then
            local tar_file
            tar_file=$(find "$tmp_dir" -maxdepth 1 -type f | head -1)
            if [[ -n "$tar_file" ]]; then
                # 通过管道传递内层 tar 给 7zz/7z 以 -ttar 模式解压
                if command -v 7zz &>/dev/null; then
                    7zz x "$tar_file" -y -bso0 -bsp0 -o"$tmp_dir" 2>/dev/null
                elif command -v 7z &>/dev/null; then
                    7z x "$tar_file" -y -bso0 -bsp0 -o"$tmp_dir" 2>/dev/null
                fi
                rm -f "$tar_file" 2>/dev/null
            fi
        fi

        # 验证解压是否成功
        if [ ! -f "$tmp_dir/debian-binary" ]; then
            echo "  警告: 解压 ${name} 失败，未找到 debian-binary" >&2
            rm -rf "$tmp_dir"
            continue
        fi

        # 解压 data.tar.* 到目标目录
        local data_tar
        for data_tar in "$tmp_dir/data.tar."*; do
            if [[ -f "$data_tar" ]]; then
                tar -xf "$data_tar" -C "$target_dir" 2>/dev/null || {
                    echo "  警告: 解压 data 包失败 (${name})" >&2
                }
            fi
        done

        rm -rf "$tmp_dir"
        count=$((count + 1))
    done

    echo "结果: ${count} 个预编译 IPK 已注入固件"
    _mark_ok "prebuilt_ipks" "${count} injected"
}


# ═══════════════════════════════════════════════════
# LED 控制：互联网状态指示灯
# ═══════════════════════════════════════════════════
install_led_control() {
    echo "正在安装 RGB LED 互联网状态指示灯（led-ctrl 服务方案）..."
    local count=0

    # 安装 led-ctl CLI 调试工具到 /sbin/
    install -Dm755 "$BASE_PATH/patches/led-ctl" "$BUILD_DIR/package/base-files/files/sbin/led-ctl" && {
        ((++count))
        echo "  → /sbin/led-ctl（CLI 调试工具）"
        _mark_ok "file_led-ctl"
    } || _mark_fail "file_led-ctl" "install failed"

    # 安装 led-ctrl 互联网监测服务
    install -Dm755 "$BASE_PATH/patches/led-ctrl.init" "$BUILD_DIR/package/base-files/files/etc/init.d/led-ctrl" && {
        ((++count))
        echo "  → /etc/init.d/led-ctrl（互联网监测服务）"
        _mark_ok "file_led-ctrl.init"
    } || _mark_fail "file_led-ctrl.init" "install failed"

    # 安装 UCI defaults 首次启动配置
    install -Dm544 "$BASE_PATH/patches/994_led_config" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/994_led_config" && {
        ((++count))
        echo "  → /etc/uci-defaults/994_led_config"
        _mark_ok "file_994_led_config"
    } || _mark_fail "file_994_led_config" "install failed"

    echo "完成: led-ctrl 服务 + UCI LED 条目已安装"
    _mark_ok "led_control" "${count}/3 files"
}
