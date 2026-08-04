# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2017-2023 <name>
#
# 本地定制：qbittorrent 后端以预编译 IPK 形式通过
# install_prebuilt_ipks() 注入固件（无法源码编译），
# 故此处去掉 LUCI_DEPENDS 中的 +qbittorrent，避免编译期依赖解析失败。

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for qBittorrent
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
