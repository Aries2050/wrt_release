#!/usr/bin/env bash
# target、kernel 与 base system 源码修正。

fix_default_set() {
    # 注入默认主题、系统设置和目标平台通用补丁。
    if [ -d "$BUILD_DIR/feeds/luci/collections/" ]; then
        find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$THEME_SET/g" {} \;
    fi

    install -Dm544 "$BASE_PATH/patches/990_set_argon_primary" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/990_set_argon_primary"
    install -Dm544 "$BASE_PATH/patches/991_custom_settings" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/991_custom_settings"
    install -Dm544 "$BASE_PATH/patches/992_set-wifi-uci.sh" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/992_set-wifi-uci.sh"
    install -Dm544 "$BASE_PATH/patches/993_run-custom-boot-scripts" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/993_run-custom-boot-scripts"

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
        install -Dm644 "$BASE_PATH/patches/$patch_file" "$miniupnpd_dir/patches/$patch_file"
    fi
}


change_dnsmasq2full() {
    if ! grep -q "dnsmasq-full" $BUILD_DIR/include/target.mk; then
        sed -i 's/dnsmasq/dnsmasq-full/g' ./include/target.mk
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
        install -Dm755 "$BASE_PATH/patches/smp_affinity" "$affinity_script_dir/base-files/etc/init.d/smp_affinity"
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
    # DTS 标签与物理颜色一致，不存在标签反置问题。
    # 真实问题: ImmortalWRT DTS 中 gpios 的 flags 为 GPIO_ACTIVE_HIGH (0x00)，
    # 但硬件为低电平有效（common anode），应使用 GPIO_ACTIVE_LOW (0x01)。
    #
    # 修复: 将 status-red/status-green/status-blue 的 gpios flags 从
    #       GPIO_ACTIVE_HIGH (0) 改为 GPIO_ACTIVE_LOW (1)
    #
    # DTS 格式示例:
    #   修复前: gpios = <&tlmm 50 GPIO_ACTIVE_HIGH>;
    #   修复后: gpios = <&tlmm 50 GPIO_ACTIVE_LOW>;
    local dts_dir dts_file

    # 查找 DTS 目录: 优先 files-6.18 内核补丁目录, 其次上游 dts/ 目录
    for dir in \
        "$BUILD_DIR/target/linux/qualcommax/files-6.18/arch/arm64/boot/dts/qcom" \
        "$BUILD_DIR/target/linux/qualcommax/dts"; do
        if [ -d "$dir" ]; then
            dts_dir="$dir"
            break
        fi
    done

    if [ -z "$dts_dir" ]; then
        dts_dir=$(find "$BUILD_DIR/target/linux/qualcommax" -path "*/boot/dts/qcom" -type d 2>/dev/null | head -1)
    fi
    if [ -z "$dts_dir" ]; then
        dts_dir=$(find "$BUILD_DIR/target/linux/qualcommax" -maxdepth 3 -type d -name "dts" 2>/dev/null | head -1)
    fi

    if [ -z "$dts_dir" ] || [ ! -d "$dts_dir" ]; then
        echo "警告: 未找到 Qualcommax DTS 目录，跳过 LED GPIO 极性修正" >&2
        return
    fi

    dts_file=$(grep -rl "status-red" "$dts_dir" 2>/dev/null | head -1)
    if [ -z "$dts_file" ]; then
        echo "警告: 未找到包含 status-red 的 DTS 文件，跳过 LED GPIO 极性修正" >&2
        return
    fi

    echo "发现 NN6000 DTS 文件: $dts_file"

    local fixed=0

    # 将 status-red/status-green/status-blue 的 GPIO flags 从 ACTIVE_HIGH 改为 ACTIVE_LOW
    for node in status-red status-green status-blue; do
        if grep -q "$node" "$dts_file"; then
            # 匹配 DTS 中 gpios 属性的两种常见写法:
            #   宏定义: gpios = <&tlmm 50 GPIO_ACTIVE_HIGH>;
            #   数值:   gpios = <&tlmm 50 0>;
            # 仅修改 flags 值（最后一个数字/宏），不改动 GPIO 编号
            sed -i "/$node {/,/};/{
                /gpios =/s/GPIO_ACTIVE_HIGH/GPIO_ACTIVE_LOW/g
                /gpios =/s/ [0-9]\+>$/ 1>/
            }" "$dts_file"
            echo "  已修正 $node GPIO flags: ACTIVE_HIGH → ACTIVE_LOW"
            fixed=1
        fi
    done

    if [ "$fixed" -eq 1 ]; then
        echo "完成: NN6000 LED GPIO 极性已从 ACTIVE_HIGH 修正为 ACTIVE_LOW"
    else
        echo "警告: 未找到需要修正的 LED 节点" >&2
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
        install -Dm755 "$BASE_PATH/patches/cpuusage" "$qualcommax_sbin_dir/cpuusage"
    fi
    if [ -d "$BUILD_DIR/target/linux/mediatek" ]; then
        install -Dm755 "$BASE_PATH/patches/hnatusage" "$filogic_sbin_dir/cpuusage"
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
        install -Dm755 "$BASE_PATH/patches/nss_diag.sh" "$file"
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
        cat >"$conf_path" <<'EOF'
/etc/AdGuardHome.yaml
/etc/easytier
/etc/lucky/
/etc/custom-boot.d/
EOF
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

    if ! wget_retry -q "$hds_url" -O "$tmp_dir/$hds_zip"; then
        echo "警告：下载 HDSentinel (${hds_arch}) 失败，尝试本地副本..." >&2
        if [[ -f "$local_zip/$hds_zip" ]]; then
            echo "使用本地副本: $local_zip/$hds_zip"
            \cp -f "$local_zip/$hds_zip" "$tmp_dir/$hds_zip"
        else
            echo "警告：本地副本也不存在 ($local_zip/$hds_zip)，跳过 HDSentinel 集成" >&2
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
    else
        echo "警告：未找到解压后的 HDSentinel 二进制文件，跳过 HDSentinel 集成" >&2
        ls -la "$tmp_dir"
        rm -rf "$tmp_dir"
        return 0
    fi

    rm -rf "$tmp_dir"
}


# ⭐ 将预编译 IPK 注入固件根文件系统（解压到 BUILD_DIR/files/）
# 用于在固件中预装 qBittorrent 等无法通过源码编译的包。
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
        "$pkg_dir/luci-app-qbittorrent_"*.ipk
        "$pkg_dir/luci-i18n-qbittorrent-zh-cn_"*.ipk
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
        elif command -v ar &>/dev/null; then
            (cd "$tmp_dir" && ar -x "$ipk") 2>/dev/null
            extracted=1
        else
            echo "  警告: 无法解压 ${name}（7zz/7z/ar 均不可用）" >&2
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
}


# ═══════════════════════════════════════════════════
# LED 控制：互联网状态指示灯
# ═══════════════════════════════════════════════════
install_led_control() {
    echo "正在安装 RGB LED 互联网状态指示灯（led-ctrl 服务方案）..."

    # 安装 led-ctl CLI 调试工具到 /sbin/
    install -Dm755 "$BASE_PATH/patches/led-ctl" "$BUILD_DIR/package/base-files/files/sbin/led-ctl"
    echo "  → /sbin/led-ctl（CLI 调试工具）"

    # 安装 led-ctrl 互联网监测服务
    install -Dm755 "$BASE_PATH/patches/led-ctrl.init" "$BUILD_DIR/package/base-files/files/etc/init.d/led-ctrl"
    echo "  → /etc/init.d/led-ctrl（互联网监测服务）"

    # 安装 UCI defaults 首次启动配置
    install -Dm544 "$BASE_PATH/patches/994_led_config" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/994_led_config"
    echo "  → /etc/uci-defaults/994_led_config"

    echo "完成: led-ctrl 服务 + UCI LED 条目已安装"
}
