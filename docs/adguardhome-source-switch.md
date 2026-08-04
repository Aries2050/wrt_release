# luci-app-adguardhome 源切换记录（kenzok8/small-package）

> 日期：2026-08-04
> 状态：**已提交**（当前提交）

## 1. 目标

将 `luci-app-adguardhome` 从**官方 openwrt/luci 源**切换为 **`kenzok8/small-package`** 提供的版本，并将 `adguardhome` 二进制核心一并编入固件（方案 B + C）。

## 2. 候选源码来源对比

| 来源 | 维护者 | 实现 | init 脚本 | 二进制来源 |
|------|--------|------|-----------|-----------|
| openwrt/luci 官方（`applications/luci-app-adguardhome`） | George Sapkin | ucode/JS 简洁版 | 小写 `/etc/init.d/adguardhome` | 强制依赖 `+adguardhome` 包 |
| **kenzok8/small-package**（根目录 `luci-app-adguardhome`） | kenzok8 | Lua CBI，功能丰富（改密/核心更新/4 种重定向） | 大写 `/etc/init.d/AdGuardHome` | `INCLUDE_binary=n` 时 LuCI 运行时检测/下载 |
| ZqinKing/luci-app-adguardhome（已停用） | ZqinKing | — | 大写 | — |

**选定：`kenzok8/small-package`**（与路由器上现存 `26.108.56344~be2cecb` 版本同源）。

## 3. 提交历史背景

| 提交 | 日期 | 说明 |
|------|------|------|
| `151b6da` | 2025-09-26 | 改用 `ZqinKing/luci-app-adguardhome` fork 直接克隆覆盖 |
| `92760ff` | 2026-04-01 | 从 immortalwrt packages feed 移除该包（避免来源冲突） |
| `541c809` | 2026-08-01 | 切回官方源：`custom_feed.sh` 移除 + 停用 ZqinKing fork |
| `b11c563` | 2026-08-01 | `verify.sh` 移除 `luci-app-adguardhome` 检查 |
| **本次（当前提交）** | 2026-08-04 | 切换到 kenzok8/small-package 源 + 二进制编入 |

## 4. 改动明细（20 个文件）

### 4.1 构建脚本（4 个）

| 文件 | 改动 | 说明 |
|------|------|------|
| `wrt_core/modules/custom_feed.sh` | `base_custom_feed_packages` 加 `luci-app-adguardhome` | 从 kenzok8/small-package 稀疏同步 |
| `wrt_core/modules/custom_feed.sh` | `required_feed_dirs` 加 `luci-app-adguardhome` | 同步结果校验 |
| `wrt_core/modules/feed_source_fixes.sh` | `remove_unwanted_packages()` 的 `luci_packages` 加 `luci-app-adguardhome` | 移除官方 luci feed 版，避免同名冲突 |
| `wrt_core/modules/verify.sh` | `required_package_dirs` 加回 `luci-app-adguardhome` | 恢复 custom_feed 安装校验 |

### 4.2 编译配置（17 个）

| 文件 | 改动 |
|------|------|
| 16 个机型 `deconfig/*.config` | 加 `CONFIG_PACKAGE_adguardhome=y`（二进制核心编入固件） |
| `deconfig/compile_base.config` | 删除 `CONFIG_PACKAGE_luci-i18n-adguardhome-zh-cn=y`（悬空） |
| `deconfig/redmi_ax6000_immwrt21.config` | 加 `CONFIG_PACKAGE_adguardhome=y` + 删除悬空翻译配置 |

> 16 个机型：aliyun_ap8220_immwrt/libwrt、cmcc_rax3000m、gemtek_w1701k、jdcloud_ax6000、jdcloud_ipq60xx_immwrt/libwrt、link_nn6000v2、linksys_mx4x00、n1、qihoo_360v6、redmi_ax5、redmi_ax6000_immwrt21、x64、zn_m2_immwrt/libwrt。

## 5. 关键验证结论

### 5.1 `luci-i18n-adguardhome-zh-cn` 悬空确认（方案 C 正确）

- 新版 kenzok8 `luci-app-adguardhome` 用 `luci.mk` 构建，但**没有 `po/` 目录**（中文硬编码在 Lua 代码，如 `translate("运维")`）。
- 因此 **不生成** `luci-i18n-adguardhome-zh-cn` 符号 → 删除 config 中的该选项是**正确的**，界面中文不受影响。

### 5.2 luci.mk 语言别名机制（其它 i18n 全部有效）

`openwrt/luci` 的 `luci.mk` 关键逻辑：

```make
LUCI_LC_ALIAS.zh_Hans=zh-cn
LUCI_LC_ALIAS.zh_Hant=zh-tw
$(foreach lang,$(LUCI_LANGUAGES),
  $(eval $(call LuciTranslation,$(firstword $(LUCI_LC_ALIAS.$(lang)) $(lang)),$(lang))))
```

即 **`po/zh_Hans` 经别名生成 `luci-i18n-<pkg>-zh-cn`**。确认以下 7 个 `luci-i18n-*-zh-cn` 配置**均有效，无需修改**：

`tailscale`、`easytier`、`oaf`（po/zh_Hans → 别名 zh-cn）、`quickstart`（po/zh-cn）、`lucky`、`mosdns`、`passwall`。

## 6. 最终包来源结构（自洽）

```
固件内包含：
├── adguardhome            ← kenzok8/small-package（二进制核心 0.107.78，小写 init）
├── luci-app-adguardhome   ← kenzok8/small-package（LuCI 界面，大写 init，中文内建）
└── 官方 luci / packages 源的两个包均已移除（无冲突）
```

行为与路由器现状一致：kenzok8 LuCI 安装时 `postinst` 自动 `stop/disable` 小写 `adguardhome` 服务，避免 init 冲突。

## 7. 验证清单（全部通过）

- [x] `custom_feed.sh` / `feed_source_fixes.sh` / `verify.sh` bash 语法 `bash -n` 通过
- [x] 16 机型 `CONFIG_PACKAGE_adguardhome=y` 幂等确认
- [x] `luci-i18n-adguardhome-zh-cn` 全部清除（无 LEAK）
- [x] kenzok8/small-package 确认含 `luci-app-adguardhome`（根目录新版）
- [x] openwrt/luci 与 immortalwrt/luci 官方均有该包（已排除来源缺失）
- [x] 所有机型勾选的 `luci-app-*` 均有来源（custom_feed / 官方 luci / 设备专用 / timsaya feed）

## 8. 建议提交信息

```
feat: luci-app-adguardhome 切换到 kenzok8/small-package 源并内置二进制

- custom_feed.sh: 从 kenzok8/small-package 同步 luci-app-adguardhome
- feed_source_fixes.sh: 移除官方 luci feed 版避免同名冲突
- verify.sh: 恢复 luci-app-adguardhome 安装校验
- 16 个机型 config: 增加 CONFIG_PACKAGE_adguardhome=y（核心编入固件）
- compile_base.config / redmi_ax6000: 清理悬空 luci-i18n-adguardhome-zh-cn
```
