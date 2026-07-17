# 本地定制更改概览

> **最后更新**: 2026-07-17

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
| Lucky 预编译二进制 | `wrt_core/prebuilt_packages/lucky_2.27.2_Linux_*.tar.gz` | Lucky 预编译二进制包，构建时注入到 lucky Makefile |

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

### 5. glibc 兼容层

| 模块 | 说明 | 状态 |
|------|------|------|
| `wrt_core/modules/glibc_compat.sh` | 运行时 glibc 兼容层：从 Debian 下载 glibc 库注入固件 | ✅ 当前方案 |
| `wrt_core/patches/glibc-compat-check.sh` | glibc 兼容性诊断脚本 | ✅ 保留 |
| `wrt_core/deconfig/glibc.config` | ~~系统级 LIBC 切换为 glibc（已废弃）~~ | ❌ 已删除 |
| `GLIBC_COMPAT=true` | 设备 INI 标记，控制 glibc 兼容层（未定义时默认 true） | ✅ 当前方案 |

**历史**：最初采用系统级 LIBC 切换（`CONFIG_LIBC="glibc"`），但上游 kconfig choice 强制重置为 musl，`make` 内部也会重新运行 defconfig 覆盖手动修改。2026-07-17 改为运行时兼容方案——固件使用 musl 编译，通过 `glibc-run` 包装脚本加载 glibc 二进制。

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
| 自动下载 HDSentinel 并注入固件 | `wrt_core/modules/target_fixes.sh` | 从 `hdsentinel.com` 按架构下载，解压后通过 `BUILD_DIR/files/bin/` 注入根文件系统（不经过 IPK 打包，避免依赖检查） |
| 本地回退包 | `wrt_core/prebuilt_packages/hdsentinel/*.zip` | 下载失败时使用仓库内本地副本 |

### 8. 自动集成预编译包（已移除：编译后复制到输出目录）

> **注**：旧方案在 `build.sh` 中将预编译 IPK 复制到 `bin/targets/*/packages/` 及 `firmware/`。该功能已由构建时注入（`install_prebuilt_ipks()` → `BUILD_DIR/files/`）替代，`build.sh` 中相关代码已清理。

### 9. 自定义启动脚本（保留每台路由器的独立修改）

| 更改 | 文件 | 说明 |
|------|------|------|
| 新增自定义启动脚本功能 | `wrt_core/patches/993_run-custom-boot-scripts` | 每次刷机/升级后首次启动，自动扫描 `/etc/custom-boot.d/` 下按数字前缀命名的子目录，并执行每个子目录中的 `apply.sh` 脚本（安全限制：固定文件名，防止意外执行任意文件）。目录隔离设计，每项非公共更改独占一个子目录（如 `01-mac-spoof/`、`02-dns-tweak/`）。该目录位于 overlay 分区（`sysupgrade` 保留） |
| 加入 sysupgrade 备份清单 | `wrt_core/modules/target_fixes.sh` | `/etc/custom-boot.d/` 已加入 `sysupgrade.conf`，与其他保留路径（AdGuardHome、easytier、lucky）一致 |

### 10. 代码质量修复

| 更改 | 文件 | 说明 |
|------|------|------|
| 运行时 glibc 兼容层替代系统级切换 | `wrt_core/modules/glibc_compat.sh`（从 `_deprecated/` 恢复） | 不再修改 `CONFIG_LIBC`，通过 `glibc-run` 包装脚本加载 glibc 二进制 |
| 删除废弃文件 | `wrt_core/deconfig/glibc.config`、`wrt_core/modules/_deprecated/` | 系统级 LIBC 切换相关文件已清理 |
| 修复 `print_usage` 中错误的 `start.sh` 引用 | `build.sh` / `wrt_core/build_container.sh` | `./start.sh` → `./build.sh` |
| 移除 `update.sh` 中重复的 `set -o errexit` | `wrt_core/update.sh` | 与 `set -e` 语义重复 |
| `COREMARK_NUMBER_OF_THREADS` 从全局移至各设备 | `wrt_core/deconfig/compile_base.config` + 各设备 `.config` | 全局 `=6` 改为各设备 `=4`（4 核设备），x64 不设置 |
| 同步 CI 设备列表，移除 N1 | `.github/workflows/release_wrt.yml` / `README.md` | 注释 N1 相关步骤，从设备表中移除 |
| Lucky 预编译包移入 `prebuilt_packages/` | `wrt_core/patches/` → `wrt_core/prebuilt_packages/` | 保持 `patches/` 目录纯文本补丁 |
| HDSentinel 支持多架构下载 | `wrt_core/modules/target_fixes.sh` | armv8 和 x64 自动选择对应版本 |
| `update.sh` 增加 DEV_NAME 参数传递 | `wrt_core/update.sh` / `build.sh` | 向下游模块传递设备名，用于架构检测 |
| 新增 `get_package_filename()` 从 Packages.gz 解析正确包路径 | `wrt_core/modules/glibc_compat.sh` | 解决 libc6→glibc 源码名不同导致的下载路径错误 |
| 白名单模式提取 glibc 库，仅保留核心运行时库 | `wrt_core/modules/glibc_compat.sh` | `extract_so_from_deb()` 改为 case 白名单，跳过非必需 .so 文件 |
| 路径/配置改为函数内延迟求值 | `wrt_core/modules/glibc_compat.sh` | 全局变量 `DEBIAN_MIRRORS`、`GLIBC_DIR` 等改为 `_glibc_*()` 辅助函数，避免 source 时变量未定义 |
| 修复 `while read \| pipe` 导致 `found` 变量作用域丢失 | `wrt_core/modules/glibc_compat.sh` | `extract_so_from_deb()` 中改用进程替代 `< <(find ...)` 替代管道 |
| 修复 `ld-linux-aarch64.so.1` 符号链接自引用问题 | `wrt_core/modules/glibc_compat.sh` | 防止 `ld-linux-aarch64.so.1 → ld-linux-aarch64.so.1` 自身链接 |
| 删除测试脚本 | `wrt_core/modules/glibc_compat.sh` 中移除的测试代码 | 清理构建调试遗留 |
| 移动设备端安装脚本到 `scripts/` | `.install_glibc_compat.sh` → `scripts/install_glibc_compat.sh` | 与构建模块分离，统一管理运行时脚本 |
| HDSentinel 设为全局命令和环境变量 | `wrt_core/modules/target_fixes.sh` | 创建 `/usr/bin/hdsentinel` 包装脚本（自动调用 `glibc-run`）及 `/etc/profile.d/hdsentinel.sh` 设置 `HDSENTINEL` 环境变量 |
| 回退 smartdns PKG_MIRROR_HASH 至 git archive 原始值 | `wrt_core/modules/package_source_updates.sh` | 移除错误的 sed 替换，`PKG_SOURCE_PROTO:=git` 应用 `5ef82e...` 而非 `fd7bfb...`，修复 CI 构建失败 |
| qBittorrent 预置固件（内置预编译 IPK） | `wrt_core/modules/target_fixes.sh` + `wrt_core/update.sh` | 新增 `install_prebuilt_ipks()`，在 `stage_pre_install_source_fixes` 中解压预编译 IPK 到 `BUILD_DIR/files/`，实现固件开机即带 qBittorrent |

## 与上游的差异标识

本地独有文件和目录（上游不存在）：

```
wrt_core/deconfig/glibc.config
wrt_core/patches/glibc-compat-check.sh
wrt_core/patches/993_run-custom-boot-scripts
wrt_core/modules/_deprecated/glibc_compat.sh
wrt_core/prebuilt_packages/
├── install.sh
├── qbittorrent.conf
├── lucky_2.27.2_Linux_arm64_wanji.tar.gz
└── lucky_2.27.2_Linux_x86_64_wanji.tar.gz
docs/
├── CHANGES.md
├── GLIBC_COMPAT.md
└── MAINTENANCE.md
```
