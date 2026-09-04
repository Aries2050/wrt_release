# QModem 集成说明

> **最后更新**: 2026-09-04

本文档记录将 [FUjr/QModem](https://github.com/FUjr/QModem)（5G/4G Modem 管理）集成进本仓库编译配置的方法与决策。

## 背景

- 曾尝试在设备上直接安装 QModem v3.2.0 **预编译 APK**（临时放置 `/tmp/1`），模拟安装（`apk add --simulate`) 报缺 5 个依赖：
  - `libubox20260708` / `libblobmsg-json20260708` —— **ABI 不匹配**：预编译包基于 libubox 2026-07-08 编译，目标固件（官方 SNAPSHOT `r0-5bf2e55`）的 libubox 为 `libubox20260213`（2026-06-19 构建）。
  - `kmod-usb-net-cdc-mbim` / `kmod-usb-net-qmi-wwan` / `kmod-usb-serial-option` —— 预编译包的 kmod 必须匹配固件内核 ABI，源中不可解析。
- **结论**：预编译包 ABI 与固件不匹配、无法可靠安装；用源码把 QModem **编译进固件**，所有库与内核模块 ABI 天然对齐。

## 接入方式

QModem 是**多包分层 feed**（`application/`、`luci/`、`driver/` 三个包目录 + 根 `version.mk` 统一版本），按官方推荐以 `src-git` 接入：

```bash
# wrt_core/modules/feeds.sh → update_feeds()
append_feed_if_missing "$FEEDS_PATH" "qmodem" "src-git qmodem https://github.com/FUjr/QModem.git;main"
```

`feeds update -a` 会拉取整个 feed；`feeds install -a -f` 递归安装其下所有软件包（`luci/` 子目录走 `feeds/luci/luci.mk` 标准流程）。

> 不采用 custom_feed 稀疏同步：QModem 是三层 feed 结构（含 `../../version.mk` 相对引用），稀疏摘出单包会破坏版本引用与 luci.mk 包含关系。

## 软件包选型（`jdcloud_ipq60xx_immwrt.config`）

| 包 | 决策 | 说明 |
|----|------|------|
| `qmodem` | `=y` 编入 | 核心控制层（纯脚本，含 AT/sms/拨号脚本） |
| `luci-app-qmodem-next` | `=y` 编入 | **新版 JS UI（官方推荐）**，自带短信界面（`sms.js`/`sms_conversation.js`/`sms_forward.js`/`sms_sim.js`） |
| `sms-forwarder-next` | `=y` 编入 | 新代短信转发器（纯脚本），next 界面的短信转发依赖 |
| `qmodem-seal` | `=y` 编入 | 加密反馈包（`PACKAGE_qmodem_INCLUDE_SEAL` 默认 y，显式固化） |
| `quectel-CM-5G-M` | `=y` 编入 | Tom 定制版 Quectel Connect Manager（`USE_TOM_CUSTOMIZED_QUECTEL_CM`，默认选项） |
| `ndisc6` | `=y` 编入 | IPv6 ND 工具（feed 内源码，来自 remlab.net，有 MD5SUM） |

> ⚠️ 未选用旧版 `luci-app-qmodem`（Lua）与 `luci-app-qmodem-sms`：`luci-app-qmodem-sms` 依赖旧版 `luci-app-qmodem`，而 old 与 next **互斥不可同装**。短信功能由 next 内置实现，无需旧短信界面包。

## 内核驱动选型

qmodem 主包的驱动依赖由 **旧版 luci-app-qmodem 的 config 选项**（`PACKAGE_luci-app-qmodem_INCLUDE_*`）联动（即使不编译旧版包，这些 Kconfig 符号仍存在、deconfig 可显式设置）。各选项**默认值**若不覆盖会拉错依赖：

| 选项 | 默认 | 本配置 | 效果 |
|------|------|--------|------|
| `INCLUDE_vendor-qmi-wwan` | ✅（choice 默认） | `=n` | 不把厂商 QMI 驱动作为 qmodem 强依赖；Quectel `kmod-qmi_wwan_q` 单独 `=y` 内置、Simcom/Fibocom `=m` 仅编译（见下） |
| `INCLUDE_generic-qmi-wwan` | ❌ | `=y` | 通用 QMI 驱动 `kmod-usb-net-qmi-wwan` 编入固件 |
| `INCLUDE_nss-qmi-wwan` | ❌ | `=n` | NSS 版驱动（仅 ipq807x/ipq50xx，ipq60xx 无关） |
| `INCLUDE_ADD_PCI_SUPPORT` | `=n` | `=n` | 关闭 PCIe/MHI 选项联动（避免 `kmod-pcie_mhi` 被强制编入） |
| `INCLUDE_ADD_MTK_T7XX_SUPPORT` | `=n` | `=n` | 关闭 MTK T7xx |
| `INCLUDE_ADD_QFIREHOSE_SUPPORT` | `=n` | `=n` | 关闭 QFirehose 刷机工具 |
| `USE_TOM_CUSTOMIZED_QUECTEL_CM` | ✅（choice 默认） | `=y` | 拉入 `quectel-CM-5G-M` |
| `INCLUDE_ndisc6` | ✅（choice 默认） | `=y` | 拉入 `ndisc6` |
| `PACKAGE_qmodem_INCLUDE_SEAL` | `=y` | `=y` | 拉入 `qmodem-seal` |

**通用 USB modem 内核模块**（qmodem 硬依赖，显式列出便于审查）编入固件：

```
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y
CONFIG_PACKAGE_kmod-usb-serial-option=y
```

（其余 `kmod-usb2/usb3/serial/net/acm/wdm/cdc-ether/rndis/cdc-ncm/huawei-cdc-ncm` 等由 qmodem 依赖自动拉入。）

### 厂商驱动：Quectel 内置，其余仅编译

厂商定制内核驱动：
- **`kmod-qmi_wwan_q`（Quectel USB QMI）`=y` 内置**——QModem 主推 Quectel 模块，编入固件即可直接使用；
- **`kmod-qmi_wwan_s`（Simcom）/ `kmod-qmi_wwan_f`（Fibocom）/ `kmod-pcie_mhi`（MHI PCIe）`=m` 仅编译**——产出 APK 不内置，需要时经 `firmware/packages/` 本地源 `apk add`。

```
CONFIG_PACKAGE_kmod-qmi_wwan_q=y   # Quectel USB QMI（driver/quectel_QMI_WWAN），内置
CONFIG_PACKAGE_kmod-qmi_wwan_s=m   # Simcom USB QMI（driver/simcom_QMI_WWAN），仅编译
CONFIG_PACKAGE_kmod-qmi_wwan_f=m   # Fibocom USB QMI（driver/fibocom_QMI_WWAN），仅编译
CONFIG_PACKAGE_kmod-pcie_mhi=m     # Quectel MHI PCIe（driver/quectel_MHI），仅编译
```

> ⚠️ **ECM RAWIP 联动（ipq60xx 无 rmnet 提供者，构建期禁用）**：上游 qca-nss-ecm 以
> `CONFIG_PACKAGE_kmod-qmi_wwan_q` 为 RAWIP 前端开关（`ifneq` 对 `=y`/`=m` **都成立**），
> 只要该符号非空就启用 `ECM_INTERFACE_RAWIP_ENABLE=y`，modpost 需要 NSS rmnet 的
> `nss_rmnet_rx_get_ifnum`。而提供该符号的 NSS rmnet 驱动（QModem `driver/nss/rmnet-nss`）
> 约束为 `@(TARGET_qualcommax_ipq807x||ipq50xx)`——**ipq60xx 无 rmnet 提供者**，
> `CONFIG_NSS_DRV_RMNET_ENABLE=y` 也无法导出该符号（曾两度因此 CI 失败：
> `ERROR: modpost: "nss_rmnet_rx_get_ifnum" [ecm.ko] undefined!`）。
> **最终方案**：构建期 `disable_qca_nss_ecm_rawip()`（`package_source_updates.sh`，
> `update.sh` stage_pre_install_source_fixes 注册）删除 `qca-nss-ecm/Makefile` 中
> `kmod-qmi_wwan_q`→RAWIP 联动整块；`kmod-qmi_wwan_q` 仍 `=y` 内置（走标准 QMI/AT），
> `kmod-qmi_wwan_s/f`、`kmod-pcie_mhi` 无类似联动，保持 `=m` 安全。

- `[m]` 包在编译期被 `make` 构建，产出 IPK/APK 由 `build.sh` 复制到 `firmware/packages/`（本地软件源索引），需要时按需 `apk add`。
- **与预编译包的根本区别**：这些 kmod 与固件同一次编译，内核 ABI 天然一致，不会出现源中不可解析/不匹配问题。

## 依赖说明

- 用户态依赖（`jq`/`bc`/`coreutils`/`coreutils-stat`/`xxd`/`usbutils`/`terminfo`/`libjson-c`/`libubus`/`libubox`/`libblobmsg-json`/`ucode` 等）全部来自 ImmortalWRT 官方 feeds，与固件同源编译，**无 ABI 问题**（这正是预编译包 `libubox20260708` 缺失的根源）。
- `ndisc6` 从 `remlab.net` 下载源码编译（feed 内 Makefile 自带 MD5SUM），CI/构建机需可访问外网。

## 构建验证

- 语法：`bash -n wrt_core/modules/feeds.sh`
- 全量构建入口：`./build.sh jdcloud_ipq60xx_immwrt`
- 构建完成后厂商驱动 APK 应在 `firmware/packages/` 下（`kmod-qmi_wwan_s*` 等；`kmod-qmi_wwan_q` 已内置）。
- 刷机后验证：`lsmod | grep -E 'qmi_wwan_q|ecm'`（内置驱动可加载）、`ubus list | grep -E 'qmodem|at-daemon'`。
- 2026-09-04 附带修复：`build.sh` 失败后自动补跑冲突检测的路径 bug——原 `$BASE_PATH/scripts`
  指向不存在的 `wrt_core/scripts/`，已改为 `$REPO_ROOT/scripts`（仓库根 `scripts/check_pkg_conflicts.py`）。

## 许可证

QModem 仓库 LICENSE 为 **MPL 2.0 + 禁止商用附加条款**（非标准 MPL 2.0）。本仓库为个人自用固件，随固件分发需保留对应版权声明。