#!/usr/bin/env bash

fix_cups_libcups_avahi_depends() {
    local makefile_path="$(get_custom_feed_worktree_dir)/cups/Makefile"
    
    # Check if file exists
    if [ ! -f "$makefile_path" ]; then
        echo "cups: libcups Makefile not found, skip: $makefile_path"
        return 0
    fi
    
    # Check if both deps already present within the libcups block only
    if sed -n '/^[[:space:]]*define Package\/libcups[[:space:]]*$/,/^[[:space:]]*endef[[:space:]]*$/p' "$makefile_path" | grep -q "+libavahi-client" && \
       sed -n '/^[[:space:]]*define Package\/libcups[[:space:]]*$/,/^[[:space:]]*endef[[:space:]]*$/p' "$makefile_path" | grep -q "+libavahi"; then
        echo "cups: libcups avahi deps already present, skip"
        return 0
    fi
    
    # Use scoped sed to modify DEPENDS only within Package/libcups block
    sed -i '/^[[:space:]]*define Package\/libcups[[:space:]]*$/,/^[[:space:]]*endef[[:space:]]*$/ {
        /DEPENDS:=/ s/$/ +libavahi-client +libavahi/
    }' "$makefile_path"
    
    echo "cups: added missing avahi deps to Package/libcups"
    return 0
}

# ⭐ 修复 luci-app-cupsd 的 CUPS 界面 500（Runtime error）：
# APK 迁移后移除 luci-lib-ipkg，page1.lua 的 require("luci.model.ipkg") 成死引用
# （页面实际未使用该模块）→ 访问 /admin/services/cupsd 报 module 'luci.model.ipkg' not found。
fix_cups_luci_ipkg_require() {
    local page1_path="$(get_custom_feed_worktree_dir)/luci-app-cupsd/root/usr/lib/lua/luci/model/cbi/cupsd/page1.lua"

    if [ ! -f "$page1_path" ]; then
        echo "cups: luci-app-cupsd page1.lua not found, skip: $page1_path"
        return 0
    fi

    if ! grep -q 'require("luci.model.ipkg")' "$page1_path"; then
        echo "cups: page1.lua 已无 luci.model.ipkg 引用，跳过"
        return 0
    fi

    sed -i '/require("luci.model.ipkg")/d' "$page1_path"
    echo "cups: 已移除 page1.lua 的 luci.model.ipkg 死引用（修复 CUPS 界面 500）"
    return 0
}
