# -*- coding: utf-8 -*-
"""检查 link_nn6000v2_immwrt.config 中启用的软件包是否在项目来源中可找到。"""
import re, os

ROOT = r"e:\Code\router\wrt_release"
wrt = os.path.join(ROOT, "wrt_core")


def extract_packages_from_config(path):
    pkgs = set()
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            m = re.match(r"^CONFIG_PACKAGE_([A-Za-z0-9_+\-\.]+)=y$", line)
            if not m:
                continue
            name = m.group(1)
            # 跳过选项类（如 _INCLUDE_binary、_NUM 等）
            if re.search(
                r"_(INCLUDE|ENABLE|NUM|MULTITHREAD|OPTIMIZE|BUILD|USE|TARGET|COMMIT|BRANCH|VERSION|SOURCE|METHOD|ZRAM|PROTO)",
                name,
            ):
                continue
            pkgs.add(name)
    return pkgs


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


config_path = os.path.join(wrt, "deconfig", "link_nn6000v2_immwrt.config")
base_path = os.path.join(wrt, "deconfig", "compile_base.config")

cfg_pkgs = extract_packages_from_config(config_path)
base_pkgs = extract_packages_from_config(base_path)

# custom_feed 提供的包
custom_feed_sh = read(os.path.join(wrt, "modules", "custom_feed.sh"))
cf_pkgs = set()
m = re.search(r"base_custom_feed_packages=\((.*?)\)", custom_feed_sh, re.S)
if m:
    cf_pkgs |= set(re.findall(r"\b([a-z0-9][a-z0-9_+\-\.]*)\b", m.group(1)))
for mm in re.finditer(r'"([^"]*\|[^"]*)"', custom_feed_sh):
    for part in mm.group(1).split("|")[3:]:
        cf_pkgs |= set(part.split())
cf_pkgs.add("luci-app-emmc-health")
m2 = re.search(r"required_feed_dirs=\((.*?)\)", custom_feed_sh, re.S)
if m2:
    cf_pkgs |= set(re.findall(r"\b([a-z0-9][a-z0-9_+\-\.]*)\b", m2.group(1)))

# package_source_updates.sh 自定义更新/新增的包
psu_pkgs = set(
    [
        "golang", "default-settings", "default-settings-chn", "luci-app-athena-led",
        "luci-app-timecontrol", "smartdns", "luci-app-smartdns", "mwan3",
        "luci-app-mwan3", "luci-app-diskman", "luci-lib-docker", "luci-app-dockerman",
        "luci-app-quickfile", "luci-theme-argon", "quickfile",
    ]
)

# prebuilt 预编译包
prebuilt = os.path.join(wrt, "prebuilt_packages", "pkgs")
pre_pkgs = set()
if os.path.isdir(prebuilt):
    for f in os.listdir(prebuilt):
        if f.endswith(".ipk"):
            pre_pkgs.add(f.split("_")[0])

known = cf_pkgs | psu_pkgs | pre_pkgs

# 预期由上游标准 feeds（luci / packages / immortalwrt）提供的包
stdlib = {
    "kmod-fs-exfat", "kmod-fs-vfat", "kmod-netlink-diag", "kmod-inet-diag", "kmod-tls", "kmod-tun",
    "kmod-usb-acm", "kmod-usb-ehci", "kmod-usb-net-huawei-cdc-ncm", "kmod-usb-net-ipheth",
    "kmod-usb-net-rndis", "kmod-usb-net-asix-ax88179", "kmod-usb-net-rtl8152",
    "kmod-usb-net-sierrawireless", "kmod-usb-ohci", "kmod-usb-serial-qualcomm",
    "kmod-usb-storage", "kmod-usb-storage-extras", "kmod-usb-storage-uas", "kmod-usb2",
    "htop", "fuse-utils", "ntfs3-mount", "openssh-sftp-server", "tcpdump", "sgdisk",
    "openssl-util", "resize2fs", "qrencode", "smartmontools-drivedb", "usbutils",
    "usbmuxd", "mii-tool", "xl2tpd", "xz-utils", "zram-swap",
    "luci-app-autoreboot", "luci-app-diskman", "luci-app-samba4", "luci-app-sqm",
    "luci-app-vlmcsd", "luci-app-dockerman", "luci-app-quickfile",
    "libopenssl-legacy", "luci-app-package-manager", "coremark", "jq", "iptables-nft", "ip6tables-nft",
    "proto-bonding", "luci-proto-wireguard", "luci-proto-relay", "automount",
    "luci-app-ttyd", "luci-app-upnp", "luci-app-wol", "luci-app-pbr", "luci-app-easymesh",
    "luci-app-openlist", "luci-app-zerotier", "luci-app-smartdns", "luci-app-oaf",
    "luci-app-openvpn-server", "default-settings", "default-settings-chn",
    "luci-app-adguardhome", "adguardhome",
}

print("=" * 72)
print("link_nn6000v2_immwrt.config 中启用的软件包来源分析")
print("=" * 72)

unmatched = []
for p in sorted(cfg_pkgs):
    if p in known:
        src, detail = "项目自定义源(custom_feed/更新/预编译)", "ok"
    elif p in stdlib:
        src, detail = "上游标准 feeds(预期存在)", "~"
    else:
        src, detail = "未找到明确来源", "??"
        unmatched.append(p)
    print(f"  [{detail:>2}] {p:<40} -> {src}")

print()
print("custom_feed 提供但当前配置未启用的包（供参考）:")
for p in sorted(cf_pkgs - cfg_pkgs - base_pkgs):
    print(f"  - {p}")

print()
if unmatched:
    print("!! 未能在项目自定义源 / 标准 feeds 白名单中匹配的包:")
    for p in unmatched:
        print(f"  - {p}")
else:
    print("所有配置包均有预期来源。")
