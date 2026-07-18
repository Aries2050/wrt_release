# 本地定制更改概览

> **最后更新**: 2026-07-19

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
| Lucky 预编译二进制 | `29273ea` | `wrt_core/prebuilt_packages/lucky_2.27.2_Linux_*.tar.gz` | Lucky 预编译二进制包，构建时注入到 lucky Makefile |

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

### 6. glibc 兼容层

| 模块 | 提交 | 说明 | 状态 |
|------|------|------|------|
| `wrt_core/modules/glibc_compat.sh` | `c280ddf`, `5c7fee7`, `93487c2` | 运行时 glibc 兼容层：从 Debian 下载 glibc 库注入固件 | ✅ 当前方案 |
| `wrt_core/patches/glibc-compat-check.sh` | `c280ddf` | glibc 兼容性诊断脚本 | ✅ 保留 |
| `wrt_core/deconfig/glibc.config` | `809a9dd`–`e3f4b2b` | ~~系统级 LIBC 切换为 glibc（已废弃）~~ | ❌ 已删除 |
| `GLIBC_COMPAT=true` | `93487c2` | 设备 INI 标记，控制 glibc 兼容层（未定义时默认 true） | ✅ 当前方案 |

**历史**：最初采用系统级 LIBC 切换（`CONFIG_LIBC="glibc"`），但上游 kconfig choice 强制重置为 musl，`make` 内部也会重新运行 defconfig 覆盖手动修改（`809a9dd`–`e3f4b2b`，2026-07-14~16）。2026-07-17（`c280ddf`）改为运行时兼容方案——固件使用 musl 编译，通过 `glibc-run` 包装脚本加载 glibc 二进制。

详见 [GLIBC_COMPAT.md](./GLIBC_COMPAT.md)。

### 7. 基础配置调整

| 更改 | 提交 | 文件 |
|------|------|------|
| 移除 `luci-app-transmission` | `d100602` | `wrt_core/deconfig/compile_base.config` |
| 默认编译配置改为 `link_nn6000v2_immwrt` | `d100602` | `.github/workflows/build_wrt.yml` |
| 添加 Go Setup 步骤 | `d100602` | `.github/workflows/build_wrt.yml` |
| NN6000v2 加入 `zram-swap` / `luci-app-emmc-health` | `cb00024` | `wrt_core/deconfig/link_nn6000v2_immwrt.config` |

### 8. 构建标识

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| LuCI 状态页构建标识改为 `compilation framework by ZqinKing, build by Aries` | `29273ea` | `wrt_core/modules/luci_fixes.sh` | 替换上游默认的 `build by ZqinKing` |

### 9. HDSentinel 硬盘检测工具

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| 自动下载 HDSentinel 并注入固件 | `deb75fa`, `76408a3` | `wrt_core/modules/target_fixes.sh` | 从 `hdsentinel.com` 按架构下载，解压后通过 `BUILD_DIR/files/bin/` 注入根文件系统 |
| 本地回退包 | `deb75fa` | `wrt_core/prebuilt_packages/hdsentinel/*.zip` | 下载失败时使用仓库内本地副本 |
| 设为全局命令和环境变量 | `76408a3` | `wrt_core/modules/target_fixes.sh` | 创建 `/usr/bin/hdsentinel` 包装脚本（自动调用 `glibc-run`）及 `/etc/profile.d/hdsentinel.sh` |

### 10. 自动集成预编译包（已移除）

> **注**：旧方案在 `build.sh` 中将预编译 IPK 复制到 `bin/targets/*/packages/` 及 `firmware/`（`d100602`）。该功能已由构建时注入（`install_prebuilt_ipks()` → `BUILD_DIR/files/`）替代，`build.sh` 中相关代码已在 `3f29ec7` 中清理。

### 11. 自定义启动脚本

| 更改 | 提交 | 文件 | 说明 |
|------|------|------|------|
| 新增自定义启动脚本功能 | `b72c741` | `wrt_core/patches/993_run-custom-boot-scripts` | 每次刷机/升级后首次启动，自动扫描 `/etc/custom-boot.d/` 下按数字前缀命名的子目录，并执行每个子目录中的 `apply.sh` 脚本（安全限制：固定文件名，防止意外执行任意文件）。目录隔离设计，每项非公共更改独占一个子目录（如 `01-mac-spoof/`、`02-dns-tweak/`）。该目录位于 overlay 分区（`sysupgrade` 保留） |
| 加入 sysupgrade 备份清单 | `b72c741` | `wrt_core/modules/target_fixes.sh` | `/etc/custom-boot.d/` 已加入 `sysupgrade.conf`，与其他保留路径（AdGuardHome、easytier、lucky）一致 |

### 12. 代码质量修复

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

### 13. RGB LED 互联网状态指示灯（5 状态服务方案）

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
