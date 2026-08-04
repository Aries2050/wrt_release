# 本地定制更改概览

> **最后更新**: 2026-08-04

本仓库源自 [ZqinKing/wrt_release](https://github.com/ZqinKing/wrt_release)，在此基础上有以下本地定制。

## 分支说明

| 仓库 | 说明 |
|------|------|
| 上游 (upstream) | `https://github.com/ZqinKing/wrt_release.git` — 原始项目 |
| 本仓库 (origin) | `https://github.com/Aries2050/wrt_release.git` — 定制分支 |

## 修订时间线

| 日期 | 提交 | 说明 |
|------|------|------|
| 2026-07-14 | `d100602` | 同步上游后重新应用本地定制（LAN 地址、编译目标、额外包） |
| 2026-07-14 | `809a9dd` | 系统级 LIBC 切换为 glibc（初始方案） |
| 2026-07-15 | `29273ea` | 代码清理：修复 `start.sh` 引用、移除重复 `set -e`、CoreMark 线程数迁移至各设备 |
| 2026-07-15 | `707f49e` | 添加 `jq` 包 |
| 2026-07-15 | `8499400` | 精简编译选项，仅保留 jdcloud_ipq60xx_immwrt 和 link_nn6000v2_immwrt |
| 2026-07-15 | `deb75fa` | HDSentinel 下载失败时使用本地副本回退 |
| 2026-07-16 | `8b9b222`–`e3f4b2b` | 多轮修复 glibc 系统级方案（defconfig 覆盖问题） |
| 2026-07-17 | `c280ddf`–`41e7e5e` | 改为运行时 glibc 兼容方案（musl 编译 + glibc-run），清理废弃文件 |
| 2026-07-17 | `5c7fee7` | 修复 Debian 包下载路径和提取逻辑 |
| 2026-07-17 | `76408a3` | HDSentinel 全局命令，移动安装脚本到 `scripts/` |
| 2026-07-17 | `95118ce` | 回退 smartdns PKG_MIRROR_HASH 至上游原始值 |
| 2026-07-17 | `3f29ec7` | 移除 `build.sh` 预编译包复制逻辑，仅保留构建时注入 |
| 2026-07-17 | `93487c2` | GLIBC_COMPAT 修复——未定义时默认 true |
| 2026-07-17 | `b72c741` | 新增自定义启动脚本功能（993_run-custom-boot-scripts） |
| 2026-07-18 | `d2a8084` | CI 安装 binutils+7zip 修复预编译 IPK 解压 |
| 2026-07-18 | `cb00024` | install_prebuilt_ipks 支持 gzip+tarball 格式；NN6000v2 加入 zram-swap/emmc-health |
| 2026-07-19 | `f08ad82` | NN6000 LED GPIO 极性修正（ACTIVE_HIGH→ACTIVE_LOW） |
| 2026-07-19 | `f514715`–`ea341f1` | 原厂 LED 脚本提取 + 文档整理 |
| 2026-07-19 | `ea4dd1c`–`99ae05c` | 固件特征指纹 + 文档修正 |
| 2026-07-19 | `0f5325b` | RGB LED 互联网状态指示灯（5 状态服务方案） |
| 2026-07-31 | 合并 `upstream/main` (`4bf1cc0`) | 合并上游：恢复 quickstart 所有存储依赖；额外完全移除清理块 |
| 2026-07-31 | LED 服务修复+亮度反转+CI验证 | 见第 14 节修复记录 |
| 2026-07-31 | 定制分支信息显示 | 在 LuCI 概览页固件版本与内核版本之间插入「定制分支」行，显示编译所基于的仓库/分支/提交哈希 |
| 2026-08-01 | 定制分支显示增强 | 双仓库格式 + zh_Hans 翻译路径修复 + 未指定提交时自动获取上游 HEAD 哈希 |
| 2026-08-01 | LED 服务全面修复 | SIGHUP 递归、read -d '' 静默失效、文件名过滤防误伤、glob 适配 7.x 内核，详见第 14 节 |
| 2026-08-01 | HDSentinel 下载验证 | 大小+zip 格式双重校验，防 HTML 错误页冒充有效下载，详见第 10 节 |
| 2026-08-01 | luci-app-adguardhome 切回官方源 | 注释 ZqinKing fork 替换逻辑，改用 openwrt/luci 官方版本 |
| 2026-08-01 | sysupgrade.conf 覆写修复 | `add_backup_info_to_sysupgrade` 中 `>` 改为 `>>`，防止清除默认备份路径 |
| 2026-08-01 | 自定义启动脚本增强 + 管理工具 | `find /` 搜索 + `.boot-enabled` 触发文件；新增 `scripts/setup_custom_boot.sh` 交互式/命令行创建任务 |
| 2026-08-04 | `luci-app-adguardhome` 切回 kenzok8/small-package 源 | custom_feed 同步该包；16 机型 `CONFIG_PACKAGE_adguardhome=y` 二进制编入；清理悬空 `luci-i18n-adguardhome-zh-cn`；详见 [adguardhome-source-switch.md](./adguardhome-source-switch.md) |

## 定制清单

### 1. 编译目标

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| 仅编译亚瑟和 NN6000v2 | `d100602`, `8499400` | `wrt_core/deconfig/jdcloud_ipq60xx_immwrt.config` / `wrt_core/deconfig/link_nn6000v2_immwrt.config` | re-cs-02、re-cs-07、redmi_ax5-jdcloud 标记为 `=n` 禁用，仅启用 jdcloud_re-ss-01 和 link_nn6000-v2；re-ss-01 加入 Dockerman |

### 2. 网络配置

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| LAN 地址改为 `192.168.199.1` | `d100602` | `wrt_core/update.sh` | 替代默认的 `192.168.1.1`，避免与光猫等设备冲突 |

### 3. 预编译包管理

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| 预编译 IPK 安装脚本 | `3f29ec7` | `wrt_core/prebuilt_packages/install.sh` | 集中管理预编译 IPK 包的安装流程（qBittorrent 5.1.4 / Qt6） |
| qBittorrent 包定义 | `cb00024` | `wrt_core/prebuilt_packages/qbittorrent.conf` | qBittorrent 默认 Web UI 配置 |
| luci-app-qbittorrent 改源码编译 | `-` | `wrt_core/packages/luci-app-qbittorrent/` + `wrt_core/modules/local_packages.sh` | 前端由预编译 IPK 改为本地源码编译（`install_local_packages()` 接入 `package/`）；预编译包仅保留 qbittorrent 后端 |
| Lucky 预编译二进制 | `29273ea` | `wrt_core/prebuilt_packages/lucky_2.27.2_Linux_*.tar.gz` | Lucky 预编译二进制包，构建时注入到 lucky Makefile |

> **来源**：qBittorrent 本体及 `luci-app-qbittorrent` 前端均来源于恩山无线论坛 [bishuiwuhen](https://www.right.com.cn/forum/space-uid-249539.html) 的帖子 <https://www.right.com.cn/forum/thread-1456090-1-1.html>。

### 4. NN6000 LED GPIO 极性修正

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| 编译时修正 GPIO 极性 flags | `f08ad82` | `wrt_core/modules/target_fixes.sh` → `fix_nn6000_led_label()` | 经 2026-07-18/19 在原厂固件和 ImmortalWRT 上逐灯交叉验证，**标签无错**（GPIO 50=🔴红、GPIO 70=🟢绿、GPIO 69=🔵蓝）。真实问题是 ImmortalWRT DTS 中 GPIO flags 为 `ACTIVE_HIGH`(0x00) 而硬件为低电平有效，改为 `ACTIVE_LOW`(0x01) |
| 构建流程中调用 | `f08ad82` | `wrt_core/update.sh` → `stage_pre_install_source_fixes` | 在源码修正阶段调用 `fix_nn6000_led_label` 修复 DTS |
| 详细分析文档 | `f08ad82` | `docs/nn6000-led-config.md` | NN6000 LED 配置完整分析：硬件映射、原厂控制逻辑（wan_net_stat.sh/repacd/WPS）、ImmortalWRT 差异、手动控制方法等 |
| 原厂 LED 脚本提取 | `f514715`, `ea341f1` | `docs/stock-firmware/led/` | 从原厂固件提取的 LED 控制脚本（wan_net_stat.sh、50-wps-hotplug.sh、repacd-led.sh 等） |
| 原厂固件特征指纹 | `ea4dd1c` | `docs/nn6000-stock-fingerprint.md` | 通过 Web/SSH 快速判断设备是否运行原厂固件的方法 |
| 文档修正 | `8c44095`–`99ae05c` | `docs/CHANGES.md`, `docs/MAINTENANCE.md`, `docs/nn6000-led-config.md`, `README.md` | 品牌更正（NN6000 非 Linksys）、LED 信息更新 |

### 5. 额外软件包

| 包 | 提交 | 说明 |
|----|------|------|
| `kmod-mt7921u` / `kmod-mt7921-firmware` / `kmod-mt7921-common` | `d100602` | MT7921U USB 无线网卡驱动和固件 |
| `luci-app-dockerman` + 中文本地化 | `d100602` | Docker 管理面板 |
| `luci-app-easymesh` | `d100602` | EasyMesh 组网 |
| `luci-app-openlist` | `d100602` | OpenList 应用 |
| `luci-app-openclash` | `d100602` | OpenClash 代理客户端 |
| `luci-app-zerotier` | `d100602` | ZeroTier 虚拟组网 |
| `luci-app-statistics` + collectd 全套插件 | `d100602` | 系统统计监控 |
| `kmod-crypto-*` 全系列 + `kmod-cryptodev` | `d100602` | Cryptographic API 内核加密模块 |
| `kmod-ipsec` / `kmod-ipsec4` / `kmod-ipsec6` | `d100602` | IPsec 支持 |
| `ca-certificates` | `d100602` | CA 根证书 |
| `adb` | `d100602` | Android Debug Bridge |
| `7z` / `bsdtar` / `bzip2` / `cfdisk` / `cli` / `fdisk` / `lz4` / `lzmadec` / `lzmainfo` / `sfdisk` / `tar` / `unzip` / `zip` | `d100602` | 压缩与磁盘工具 |
| `openvpn-openssl` + `luci-app-openvpn-server`（DCO / FRAGMENT / LZ4） | `d100602` | OpenVPN 服务端 |
| `tailscale` + `luci-app-tailscale` | `d100602` | Tailscale 虚拟组网（从 custom_feed 拉取） |
| `jq` | `707f49e` | JSON 命令行处理工具 |
| `adguardhome` + `luci-app-adguardhome` | 当前提交 | AdGuardHome 切换 kenzok8/small-package 源，16 机型二进制核心编入固件；详见 [adguardhome-source-switch.md](./adguardhome-source-switch.md) |

### 6. 定制分支信息行

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| LuCI 概览页插入「定制分支」行 | 当前 | `wrt_core/modules/luci_fixes.sh` → `set_build_signature()` | 在状态页「固件版本」与「内核版本」之间新增一行，显示编译来源 |
| 双仓库显示格式 | 当前 | `wrt_core/modules/luci_fixes.sh` | 显示 `Aries2050/wrt_release@main(哈希) 基于 VIKINGYFY/immortalwrt@main(哈希) 编译`：定制仓库（wrt_release）分支/哈希取自 `git remote/rev-parse`，上游仓库取自 `REPO_URL`/`REPO_BRANCH` |
| 自动获取上游哈希 | 当前 | `wrt_core/modules/luci_fixes.sh` | 未指定 `COMMIT_HASH`（`none`/空）时，从 `stage_repo_checkout` 已检出的 `$BUILD_DIR` 读取上游 HEAD 哈希 |
| 中文翻译注入 | 当前 | `wrt_core/modules/luci_fixes.sh` + CI | i18n key `_('Custom Branch')`，中文翻译写入 **`po/zh_Hans/`**（ImmortalWRT 简体中文目录，兼容 `zh-cn`/`zh_CN`） |

### 7. glibc 兼容层

| 模块 | 提交 | 说明 | 状态 |
|------|------|------|------|
| `wrt_core/modules/glibc_compat.sh` | `c280ddf`, `5c7fee7`, `93487c2` | 运行时 glibc 兼容层：从 Debian 下载 glibc 库注入固件 | ✅ 当前方案 |
| `wrt_core/patches/glibc-compat-check.sh` | `c280ddf` | glibc 兼容性诊断脚本 | ✅ 保留 |
| `wrt_core/deconfig/glibc.config` | `809a9dd`–`e3f4b2b` | ~~系统级 LIBC 切换为 glibc（已废弃）~~ | ❌ 已删除 |
| `GLIBC_COMPAT=true` | `93487c2` | 设备 INI 标记，控制 glibc 兼容层（未定义时默认 true） | ✅ 当前方案 |

**历史**：最初采用系统级 LIBC 切换（`CONFIG_LIBC="glibc"`），但上游 kconfig choice 强制重置为 musl，`make` 内部也会重新运行 defconfig 覆盖手动修改（`809a9dd`–`e3f4b2b`，2026-07-14~16）。2026-07-17（`c280ddf`）改为运行时兼容方案——固件使用 musl 编译，通过 `glibc-run` 包装脚本加载 glibc 二进制。

详见 [GLIBC_COMPAT.md](./GLIBC_COMPAT.md)。

### 8. 基础配置调整

| 更改 | 提交 | 文件 |
|------|------|------|
| 移除 `luci-app-transmission` | `d100602` | `wrt_core/deconfig/compile_base.config` |
| 默认编译配置改为 `link_nn6000v2_immwrt` | `d100602` | `.github/workflows/build_wrt.yml` |
| 添加 Go Setup 步骤 | `d100602` | `.github/workflows/build_wrt.yml` |
| NN6000v2 加入 `zram-swap` / `luci-app-emmc-health` | `cb00024` | `wrt_core/deconfig/link_nn6000v2_immwrt.config` |

### 9. 构建标识

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| LuCI 状态页构建标识改为 `compilation framework by ZqinKing, build by Aries` | `29273ea` | `wrt_core/modules/luci_fixes.sh` | 替换上游默认的 `build by ZqinKing` |

### 10. HDSentinel 硬盘检测工具

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| 自动下载 HDSentinel 并注入固件 | `deb75fa`, `76408a3` | `wrt_core/modules/target_fixes.sh` | 从 `hdsentinel.com` 按架构下载，解压后通过 `BUILD_DIR/files/bin/` 注入根文件系统 |
| 本地回退包 | `deb75fa` | `wrt_core/prebuilt_packages/hdsentinel/*.zip` | 下载失败时使用仓库内本地副本 |
| 设为全局命令和环境变量 | `76408a3` | `wrt_core/modules/target_fixes.sh` | 创建 `/usr/bin/hdsentinel` 包装脚本（自动调用 `glibc-run`）及 `/etc/profile.d/hdsentinel.sh` |
| 下载文件有效性验证 | 2026-08-01 | `wrt_core/modules/target_fixes.sh` | 大小 < 512KB 或非有效 zip → 自动回退本地副本；三阶段 `use_local` 标志统一回退入口 |

### 11. 自动集成预编译包（已移除）

> **注**：旧方案在 `build.sh` 中将预编译 IPK 复制到 `bin/targets/*/packages/` 及 `firmware/`（`d100602`）。该功能已由构建时注入（`install_prebuilt_ipks()` → `BUILD_DIR/files/`）替代，`build.sh` 中相关代码已在 `3f29ec7` 中清理。

### 12. 自定义启动脚本

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| 新增自定义启动脚本功能 | `b72c741` | `wrt_core/patches/993_run-custom-boot-scripts` | 刷机/升级后首次启动时执行一次（UCI defaults 机制），日常重启不重复执行。`find /` 搜索 `custom-boot.d`，需 `.boot-enabled` 触发文件 |
| 加入 sysupgrade 备份清单 | `b72c741` | `wrt_core/modules/target_fixes.sh` | `/etc/custom-boot.d/` 已加入 `sysupgrade.conf` |
| 2026-08-01 增强 | 当前 | `wrt_core/patches/993_run-custom-boot-scripts` | 从硬编码 `/etc/` 改为 `find / -maxdepth 4` 搜索（支持 USB 等外部存储）；新增 `.boot-enabled` 触发文件机制 |
| 加入 sysupgrade 备份清单 | `b72c741` | `wrt_core/modules/target_fixes.sh` | `/etc/custom-boot.d/` 已加入 `sysupgrade.conf`，与其他保留路径（AdGuardHome、easytier、lucky）一致 |
| 2026-08-01 修复 `>` → `>>` | 当前 | `wrt_core/modules/target_fixes.sh` | `add_backup_info_to_sysupgrade()` 原先用 `>` 覆写整个 `sysupgrade.conf`，改为 `>>` 追加，保留默认内容 |

> **持久化说明**：`/etc/custom-boot.d/` 位于 overlay 分区。sysupgrade 两种模式（保留/不保留设置）均通过 `sysupgrade.conf` 保留该目录。唯一丢失场景是恢复出厂设置（`firstboot`）——这是预期行为。升级后 UCI defaults 会重新执行所有 `apply.sh`，因此脚本**必须幂等**。

### 13. 代码质量修复

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| 运行时 glibc 兼容层替代系统级切换 | `c280ddf` | `wrt_core/modules/glibc_compat.sh`（从 `_deprecated/` 恢复） | 不再修改 `CONFIG_LIBC`，通过 `glibc-run` 包装脚本加载 glibc 二进制 |
| 删除废弃文件 | `d9d99d5` | `wrt_core/deconfig/glibc.config`、`wrt_core/modules/_deprecated/` | 系统级 LIBC 切换相关文件已清理 |
| 修复 `print_usage` 中错误的 `start.sh` 引用 | `29273ea` | `build.sh` / `wrt_core/build_container.sh` | `./start.sh` → `./build.sh` |
| 移除 `update.sh` 中重复的 `set -o errexit` | `29273ea` | `wrt_core/update.sh` | 与 `set -e` 语义重复 |
| `COREMARK_NUMBER_OF_THREADS` 从全局移至各设备 | `29273ea` | `wrt_core/deconfig/compile_base.config` + 各设备 `.config` | 全局 `=6` 改为各设备 `=4`（4 核设备），x64 不设置 |
| 同步 CI 设备列表，移除 N1 | `29273ea` | `.github/workflows/release_wrt.yml` / `README.md` | 注释 N1 相关步骤，从设备表中移除 |
| Lucky 预编译包移入 `prebuilt_packages/` | `29273ea` | `wrt_core/patches/` → `wrt_core/prebuilt_packages/` | 保持 `patches/` 目录纯文本补丁 |
| HDSentinel 支持多架构下载 | `76408a3` | `wrt_core/modules/target_fixes.sh` | armv8 和 x64 自动选择对应版本 |
| `update.sh` 增加 DEV_NAME 参数传递 | `76408a3` | `wrt_core/update.sh` / `build.sh` | 向下游模块传递设备名，用于架构检测 |
| 新增 `get_package_filename()` 解析正确包路径 | `5c7fee7` | `wrt_core/modules/glibc_compat.sh` | 解决 libc6→glibc 源码名不同导致的下载路径错误 |
| 白名单模式提取 glibc 库 | `5c7fee7` | `wrt_core/modules/glibc_compat.sh` | `extract_so_from_deb()` 改为 case 白名单，跳过非必需 .so 文件 |
| 路径/配置改为函数内延迟求值 | `5c7fee7` | `wrt_core/modules/glibc_compat.sh` | 全局变量改为 `_glibc_*()` 辅助函数，避免 source 时未定义 |
| 修复 `while read \| pipe` 变量作用域丢失 | `5c7fee7` | `wrt_core/modules/glibc_compat.sh` | 改用进程替代 `< <(find ...)` 替代管道 |
| 修复 `ld-linux-aarch64.so.1` 符号链接自引用 | `5c7fee7` | `wrt_core/modules/glibc_compat.sh` | 防止 `.so.1 → 自身` 链接 |
| 删除测试脚本 | `5c7fee7` | `wrt_core/modules/glibc_compat.sh` | 清理构建调试遗留 |
| 移动设备端安装脚本到 `scripts/` | `76408a3` | `.install_glibc_compat.sh` → `scripts/install_glibc_compat.sh` | 与构建模块分离 |
| 回退 smartdns PKG_MIRROR_HASH | `95118ce` | `wrt_core/modules/package_source_updates.sh` | 移除错误的 sed，`PKG_SOURCE_PROTO:=git` 应用正确 hash |
| qBittorrent 预置固件（内置预编译 IPK） | `3f29ec7` | `wrt_core/modules/target_fixes.sh` + `wrt_core/update.sh` | 新增 `install_prebuilt_ipks()`，解压 IPK 到 `BUILD_DIR/files/` |
| CI 安装 7zip/binutils 修复解压 | `d2a8084` | `.github/workflows/build_wrt.yml` / `release_wrt.yml` | CI 安装 `binutils`(ar) 和 `7zip`(7zz) |
| install_prebuilt_ipks 解压兜底 | `cb00024` | `wrt_core/modules/target_fixes.sh` | 支持 gzip+tarball 格式 IPK；后移除已无用的 `ar` 兜底 |
| sysupgrade.conf 覆写修复 | 2026-08-01 | `wrt_core/modules/target_fixes.sh` → `add_backup_info_to_sysupgrade()` | `cat >` 改为 `cat >>`，防止清除 sysupgrade.conf 默认备份路径 |

### 14. RGB LED 互联网状态指示灯（5 状态服务方案）

> 引入于 `0f5325b`（2026-07-19）。三色为同一 RGB 灯珠（混色），由 `/etc/init.d/led-ctrl` 服务集中管理，**每次只亮需要的 LED，避免非预期混色**。

| 更改 | 文件 | 说明 |
|------|------|------|
| LED CLI 工具 | `wrt_core/patches/led-ctl` | `/sbin/led-ctl` 命令行调试工具，支持 `mode no-link/dialing/no-inet/connected/active` |
| LED 联网监测服务 | `wrt_core/patches/led-ctrl.init` | `/etc/init.d/led-ctrl` procd 服务，5 状态状态机 + 流量速率检测 |
| UCI 默认 LED 配置 | `wrt_core/patches/994_led_config` | 首次启动注册 LED 条目到 LuCI + 启用 led-ctrl 服务 |
| 构建集成 | `wrt_core/modules/target_fixes.sh` → `install_led_control()` | 在构建时注入上述文件 |

**5 状态定义：**

| 灯光 | 状态 | 触发条件 |
|------|------|----------|
| 🔴 红常亮 | `no-link` | WAN 接口 down（网线未插） |
| 🟡 黄快闪 (300ms) | `dialing` | WAN 接口 pending（PPPoE 拨号/获取地址） |
| 🟡 黄常亮 | `no-inet` | WAN up 但 ping 不通目标 |
| 🟢 绿常亮 | `connected` | 互联网已连接，无数据活动 |
| 🟢 绿闪烁（间隔可变） | `active` | 有数据活动，闪烁间隔随速率变短 |

**绿灯闪烁间隔自适应（上下行合计，1000M下/60M上）：**

| 速率 (rx+tx) | 亮/灭间隔 | 周期 | 说明 |
|------|----------|------|------|
| < 10KB/s | 常亮 | — | 空闲 |
| 10KB~100KB/s | 200ms / 1000ms | 1.2s | 短闪长等，最慢 |
| 100KB~1MB/s | 300ms / 500ms | 800ms | 一般活动 |
| 1MB~10MB/s | 200ms / 200ms | 400ms | 50% 占空，活跃 |
| 10MB~50MB/s | 100ms / 100ms | 200ms | 快闪 |
| > 50MB/s | 50ms / 50ms | 100ms | 极速 |

**修复记录：**

| 修复 | 说明 |
|------|------|
| rc.common case 冲突 | 底部 `case ... *) . /etc/rc.common` 导致递归 source，服务无法启动。改为 `if [ "\$1" = "_daemon" ]; then daemon_loop; fi` |
| brightness 值域 | `fix_nn6000_led_label` 修正为 ACTIVE_LOW 后 `max_brightness=1`（二进制开关），写入 `255` 被截断。全部改为 `1` |
| timer trigger 重置 brightness | 切换到 timer trigger 时内核重置 brightness=0。操作顺序改为 none→亮度→timer→delay→再设亮度 |
| DTS 搜索过宽 | `fix_nn6000_led_label` 中 `grep -rl status-red \| head -1` 搜到 ipq807x 的 DTS 而非 NN6000 的。改为优先 ipq60xx 子目录，次选排除 ipq807x |
| procd `$0` 路径错误 | `procd_set_param command /bin/sh "\$0" _daemon` 中 `\$0` 在 rc.common shebang 下解析为 `/etc/rc.common`，导致 procd 执行 `/bin/sh /etc/rc.common _daemon`（缺少脚本路径）。改为硬编码 `/etc/init.d/led-ctrl` |
| 极性反转未生效 | `fix_nn6000_led_label` 修正未写入编译产物，DTS 中 `gpios flags=0 (GPIO_ACTIVE_HIGH)`，无 `active-low;` 属性。共阳硬件下 `brightness=0`=亮、`1`=灭，与代码假设相反 |
| 方案选择 | 采用 **方案 A**：依赖 DTS 修正（`target_fixes.sh` 中保留修正，并增加 `active-low;` 属性），源文件恢复标准逻辑（`brightness=1=亮`）；当前运行固件通过 SCP 部署软件反转版临时工作 |
| `cmd_status` 颜色推断 | 推断条件写 `"255"` 但 `max_brightness=1`，sysfs 读回 `1`，颜色推断始终不显示。改为匹配 `"1"` |
| CRLF 行尾破坏 shebang | 源文件为 Windows CRLF，`#!/bin/sh\r` 导致内核找不到解释器 → `not found`。通过 SCP 上传（而非管道）避免行尾转换 |
| DTS 修正搜索路径错误 | `fix_nn6000_led_label` 只搜 `files-6.18/` 和 `dts/`，但 NN6000 DTS 实际以内核补丁形式存在于 `patches-6.18/` 中，修正从未生效。改为搜索 `patches-6.*/`、`files-6.*/`、`dts/`，支持 `.dts`/`.dtsi`/`.patch` 文件 |
| **2026-08-01 全面修复** | |
| SIGHUP 无限递归 | daemon trap 触发 `reload_service` 再向自身发 HUP → 无限递归卡死。trap 改为仅重置 `_MODE=""` |
| `read -d ''` 静默失效 | `grep -l` 输出为 newline 非 NUL，`read -d ''` 导致 found_files 永远为空，函数直接 return。改为 `read -r` |
| 误伤其他 IPQ60xx 设备 | `grep -rl "status-red"` 匹配了 `ipq6010-philips.dtsi` 和 `ipq8070-rm2-6.dts`（GPIO 完全不同）。添加文件名过滤 `*link*\|*nn6000*` |
| glob 硬编码 6.x | `patches-6.*`/`files-6.*` 到 7.x 内核静默失效。改为 `patches-[0-9]*`/`files-[0-9]*` |
| `.patch` 文件 `active-low;` 缺 `+` 前缀 | 两阶段 sed：对 `+` 行和普通行分别处理 |
| `led-ctl` brightness 不一致 | `cmd_mode` 使用 255 而其他使用 1，统一为 1 |
| 移除死代码 sed 模式 | `s/ [0-9]\+>$/ 1>/` 永不匹配（DTS 使用宏名而非数值），已删除 |
| `((count++))` 导致 install 标记误报 | `count=0` 时 `((0++))` 返回 exit 1，触发 `\|\| _mark_fail` 覆盖已写入的 OK。改为 `((++count))`（前自增）+ `_mark_ok` 移到 block 末尾 |
| grep ERR trap 噪音 | `set -o errtrace` 下 grep 无匹配返回 1 触发 error_handler。加 `\|\| true` 抑制 |
| CI 独立 DTS 验证 | 4a. 独立查找 `*link*`/`*nn6000*` 验证 GPIO_ACTIVE_LOW；4b. `sed -n '/status-red {/,/};/{ /gpios =.*GPIO_ACTIVE_LOW/p }'` 精确检查其他设备 LED 节点是否被误伤 |
| 启动默认改为绿灯常亮 | `daemon_loop` 初始 `set_mode "no-link"`（红灯）→ `set_mode "connected"`（绿灯），状态机后续根据实际网络状态调整 |

### 15. CI 验证步骤

| 更改 | 文件 | 说明 |
|------|------|------|
| 新增 Verify Customizations | `.github/workflows/build_wrt.yml` / `release_wrt.yml` | Build Firmware 后检查定制是否生效 |
| 2026-08-01 DTS 独立验证 + 误伤检查 | 同上 | 4a. 文件名过滤查找 Link/NN6000 DTS 并验证 GPIO_ACTIVE_LOW；4b. 精确 sed 检查非 NN6000 文件的 LED 节点是否被误改 |
| 2026-08-01 HDSentinel 检查 | 同上 | 新增 HDSentinel 可执行文件存在性检查（soft check） |
| 2026-08-01 构建标记系统 | 同上 + `wrt_core/modules/*.sh` | 新增 24 个构建标记（`$BUILD_DIR/.build_marks/`），各定制步骤主动上报成功/失败，CI 优先读取标记而非 grep/find 猜测 |

**验证项：**
1. LED 控制文件（`led-ctl`、`led-ctrl.init`、`994_led_config`）
2. UCI defaults（Argon 主题、系统设置、WiFi 配置器、自定义启动框架）
3. 诊断脚本（`tempinfo`、`cpuusage`、`hnatusage`、`nss_diag.sh`）
3.5. HDSentinel 硬盘检测工具（文件存在 + 可执行）
4. DTS LED 极性修正（仅 NN6000 模型）
5. 补丁部署
6. 预编译 IPK 可用性
7. 固件产物完整性

### 16. 恢复 quickstart 存储依赖

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| 移除 quickstart 非必要存储依赖的 sed 清理块 | 合并 `upstream/main` (`4bf1cc0`) | `wrt_core/modules/feed_source_fixes.sh` → `fix_quickstart()` | 合并上游提交 `4bf1cc0`（恢复 `smartd`），并进一步删除整个移除块——包括 `+smartmontools-drivedb`、`+smartmontools`、`+smartd`、`+mdadm`、`+parted`、`+e2fsprogs` 的 sed 命令 |

**背景**：上游提交 `b42aa78`（2026-07-08）添加了移除 quickstart 非必要存储依赖的 sed 逻辑。该逻辑导致 `smartd`（S.M.A.R.T. 监控守护进程）被移除，进而造成 iStoreX 首页磁盘信息无法正常显示（Issue #194）。上游已在 `4bf1cc0` 修复并恢复 `smartd`。

本次合入 `upstream/main`（`4bf1cc0`）后，在此基础上进一步移除整个依赖清理块，不再干预 quickstart 的任何依赖项。`fix_quickstart()` 现仅保留 `istore_backend.lua` 下载修复逻辑。

## 与上游的差异标识

本地独有文件和目录（上游不存在）：

```
wrt_core/patches/glibc-compat-check.sh
wrt_core/patches/led-ctl
wrt_core/patches/led-ctrl.init
wrt_core/patches/994_led_config
wrt_core/patches/993_run-custom-boot-scripts
wrt_core/prebuilt_packages/
├── install.sh
├── qbittorrent.conf
├── hdsentinel/
├── lucky_2.27.2_Linux_arm64_wanji.tar.gz
└── lucky_2.27.2_Linux_x86_64_wanji.tar.gz
scripts/
├── install_glibc_compat.sh
└── check_stock_leds.sh
docs/
├── adguardhome-source-switch.md
├── CHANGES.md
├── GLIBC_COMPAT.md
├── MAINTENANCE.md
├── nn6000-led-config.md
├── nn6000-stock-fingerprint.md
└── stock-firmware/
    └── led/
        ├── README.md
        ├── wan_net_stat.sh
        ├── 50-wps-hotplug.sh
        ├── repacd-led.sh
        ├── led.init
        └── any_rclocal.init
```
