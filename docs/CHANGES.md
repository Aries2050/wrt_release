# 本地定制更改概览

> **最后更新**: 2026-07-14

本仓库源自 [ZqinKing/wrt_release](https://github.com/ZqinKing/wrt_release)，在此基础上有以下本地定制。

## 分支说明

| 仓库 | 说明 |
|------|------|
| 上游 (upstream) | `https://github.com/ZqinKing/wrt_release.git` — 原始项目 |
| 本仓库 (origin) | `https://github.com/Aries2050/wrt_release.git` — 定制分支 |

## 定制清单

### 1. 编译目标

| 更改 | 文件 | 说明 |
|------|------|------|
| 仅编译亚瑟和 NN6000v2 | `wrt_core/deconfig/jdcloud_ipq60xx_immwrt.config` / `wrt_core/deconfig/link_nn6000v2_immwrt.config` | re-cs-02、re-cs-07、redmi_ax5-jdcloud 标记为 `=n` 禁用，仅启用 jdcloud_re-ss-01 和 link_nn6000-v2；re-ss-01 加入 Dockerman |

### 2. 网络配置

| 更改 | 文件 | 说明 |
|------|------|------|
| LAN 地址改为 `192.168.199.1` | `wrt_core/update.sh` | 替代默认的 `192.168.1.1`，避免与光猫等设备冲突 |

### 3. 预编译包管理

| 更改 | 文件 | 说明 |
|------|------|------|
| 预编译 IPK 安装脚本 | `wrt_core/prebuilt_packages/install.sh` | 集中管理预编译 IPK 包的安装流程（qBittorrent 5.1.4 / Qt6） |
| qBittorrent 包定义 | `wrt_core/prebuilt_packages/qbittorrent.conf` | qBittorrent 默认 Web UI 配置 |

### 4. 额外软件包

| 包 | 说明 |
|----|------|
| `kmod-mt7921u` / `kmod-mt7921-firmware` / `kmod-mt7921-common` | MT7921U USB 无线网卡驱动和固件 |
| `luci-app-dockerman` + 中文本地化 | Docker 管理面板 |
| `luci-app-easymesh` | EasyMesh 组网 |
| `luci-app-openlist` | OpenList 应用 |
| `luci-app-openclash` | OpenClash 代理客户端 |
| `luci-app-zerotier` | ZeroTier 虚拟组网 |
| `luci-app-statistics` + collectd 全套插件 | 系统统计监控 |
| `kmod-crypto-*` 全系列（acompress / aead / arc4 / authenc / blake2b / cbc / ccm / chacha20poly1305 / cmac / crc32 / crc32c / ctr / cts / deflate / des / ecb / ecdh / echainiv / essiv / fcrypt / gcm / geniv / gf128 / ghash / hash / hmac / kpp / lib-chacha20 / lib-chacha20poly1305 / lib-curve25519 / lib-poly1305 / manager / md4 / md5 / michael-mic / misc / null / pcbc / rmd160 / rng / seqiv / sha1 / sha256 / sha3 / sha512 / test / user / xcbc / xts / xxhash） + `kmod-cryptodev` | Cryptographic API 内核加密模块 |
| `kmod-ipsec` / `kmod-ipsec4` / `kmod-ipsec6` | IPsec 支持 |
| `ca-certificates` | CA 根证书 |
| `adb` | Android Debug Bridge |
| `7z` / `bsdtar` / `bzip2` / `cfdisk` / `cli` / `fdisk` / `lz4` / `lzmadec` / `lzmainfo` / `sfdisk` / `tar` / `unzip` / `zip` | 压缩与磁盘工具 |
| `openvpn-openssl` + `luci-app-openvpn-server`（开启 DCO / FRAGMENT / LZ4） | OpenVPN 服务端 |
| `tailscale` + `luci-app-tailscale` | Tailscale 虚拟组网（从 custom_feed 拉取） |

### 5. glibc 兼容层（新增）

| 模块 | 说明 |
|------|------|
| `wrt_core/deconfig/glibc.config` | 系统级 LIBC 切换为 glibc（替代 musl） |
| `wrt_core/patches/glibc-compat-check.sh` | glibc 兼容性诊断脚本 |
| `GLIBC_COMPAT=true` | 设备 INI 标记，启用后固件使用 glibc 编译 |

详见 [GLIBC_COMPAT.md](./GLIBC_COMPAT.md)。

### 6. 基础配置调整

| 更改 | 文件 |
|------|------|
| 移除 `luci-app-transmission` | `wrt_core/deconfig/compile_base.config` |
| 默认编译配置改为 `link_nn6000v2_immwrt` | `.github/workflows/build_wrt.yml` |
| 添加 Go Setup 步骤 | `.github/workflows/build_wrt.yml` |

### 7. 构建标识

| 更改 | 文件 | 说明 |
|------|------|------|
| LuCI 状态页构建标识改为 `compilation framework by ZqinKing, build by Aries` | `wrt_core/modules/luci_fixes.sh` | 替换上游默认的 `build by ZqinKing` |

### 7. HDSentinel 硬盘检测工具

| 更改 | 文件 | 说明 |
|------|------|------|
| 自动下载 HDSentinel 并安装到 `/bin/HDSentinel` | `wrt_core/modules/target_fixes.sh` / `wrt_core/update.sh` | 从 `hdsentinel.com` 下载 armv8 版，解压后安装到 base-files |

### 8. 自动集成预编译包

| 更改 | 文件 | 说明 |
|------|------|------|
| 编译后自动复制预编译 IPK 到固件输出 | `build.sh` | 构建完成后将 `prebuilt_packages/pkgs/*.ipk` 复制到 `bin/targets/*/packages/` 及 `firmware/`，使其在设备 opkg 和固件下载目录中可用 |

## 与上游的差异标识

本地独有文件和目录（上游不存在）：

```
wrt_core/deconfig/glibc.config
wrt_core/patches/glibc-compat-check.sh
wrt_core/prebuilt_packages/
├── install.sh
└── qbittorrent.conf
docs/
├── CHANGES.md
├── GLIBC_COMPAT.md
└── MAINTENANCE.md
```
