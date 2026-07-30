#!/usr/bin/env bash
# LuCI 展示、菜单和前端相关修正。

set_build_signature() {
    local file="$BUILD_DIR/feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
    if [ -d "$(dirname "$file")" ] && [ -f $file ]; then
        # sed -i "s/(\(luciversion || ''\))/(\1) + (' compilation framework by ZqinKing, build by Aries')/g" "$file"

        # 插入定制分支信息行（固件版本与内核版本之间）
        local repo_short
        repo_short=$(echo "$REPO_URL" | sed -E 's|https?://[^/]+/||; s|\.git$||')
        local branch_info="${repo_short} @ ${REPO_BRANCH}"
        if [ "$COMMIT_HASH" != "none" ] && [ -n "$COMMIT_HASH" ]; then
            branch_info="${branch_info} (${COMMIT_HASH:0:7})"
        fi
        # 转义 sed 替换字符串中的特殊字符
        branch_info=$(printf '%s\n' "$branch_info" | sed 's/[\/&]/\\&/g')
        sed -i "/_('Firmware Version')/a\\
\t\t\t_('Custom Branch'),\t'${branch_info}'," "$file"

        # 快速自检：确认插入生效（若上游重构 10_system.js 导致 sed 失效，此处提前暴露）
        if ! grep -q "_('Custom Branch')" "$file" 2>/dev/null; then
            echo "错误：set_build_signature — 在 $file 中未找到 _('Custom Branch')，sed 可能因上游重构而失效。" >&2
            exit 1
        fi

        # 添加中文翻译到 luci-mod-status 的 .po 文件
        local po_file="$BUILD_DIR/feeds/luci/modules/luci-mod-status/po/zh-cn/luci-mod-status.po"
        if [ -f "$po_file" ]; then
            # 检查是否已存在翻译条目，避免重复插入
            if ! grep -q '"Custom Branch"' "$po_file"; then
                cat >> "$po_file" <<EOF

#: htdocs/luci-static/resources/view/status/include/10_system.js:0
msgid "Custom Branch"
msgstr "定制分支"
EOF
            fi
        fi
    fi
}

update_menu_location() {
    local samba4_path="$BUILD_DIR/feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/luci-app-samba4.json"
    if [ -d "$(dirname "$samba4_path")" ] && [ -f "$samba4_path" ]; then
        sed -i 's/nas/services/g' "$samba4_path"
    fi

    local tailscale_path="$(get_custom_feed_worktree_dir)/luci-app-tailscale/root/usr/share/luci/menu.d/luci-app-tailscale.json"
    if [ -d "$(dirname "$tailscale_path")" ] && [ -f "$tailscale_path" ]; then
        sed -i 's/services/vpn/g' "$tailscale_path"
    fi
}


update_nginx_ubus_module() {
    local makefile_path="$BUILD_DIR/feeds/packages/net/nginx/Makefile"
    local source_date="2024-03-02"
    local source_version="564fa3e9c2b04ea298ea659b793480415da26415"
    local mirror_hash="92c9ab94d88a2fe8d7d1e8a15d15cfc4d529fdc357ed96d22b65d5da3dd24d7f"

    if [ -f "$makefile_path" ]; then
        sed -i "s/SOURCE_DATE:=2020-09-06/SOURCE_DATE:=$source_date/g" "$makefile_path"
        sed -i "s/SOURCE_VERSION:=b2d7260dcb428b2fb65540edb28d7538602b4a26/SOURCE_VERSION:=$source_version/g" "$makefile_path"
        sed -i "s/MIRROR_HASH:=515bb9d355ad80916f594046a45c190a68fb6554d6795a54ca15cab8bdd12fda/MIRROR_HASH:=$mirror_hash/g" "$makefile_path"
        echo "已更新 nginx-mod-ubus 模块的 SOURCE_DATE, SOURCE_VERSION 和 MIRROR_HASH。"
    else
        echo "错误：未找到 $makefile_path 文件，无法更新 nginx-mod-ubus 模块。" >&2
    fi
}
