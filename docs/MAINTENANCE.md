# 维护指南

> **最后更新**: 2026-07-15

## 仓库结构

```
wrt_release/
├── build.sh                          ← 入口脚本：选择设备、调用构建流程
├── wrt_core/
│   ├── update.sh                     ← 核心构建流程：拉取源码 → 应用补丁 → 编译
│   ├── pre_clone_action.sh           ← GitHub Actions 预克隆操作
│   ├── compilecfg/                   ← 设备编译配置（.ini）
│   │   ├── <device>.ini              ← 每设备一行：仓库URL、分支、目标
│   ├── deconfig/                     ← OpenWRT .config 配置片段
│   │   ├── compile_base.config       ← 基础配置（所有设备共享）
│   │   ├── <device>.config           ← 设备专属配置
│   ├── modules/                      ← 构建模块（按职责拆分）
│   │   ├── repo.sh                   ← 上游源码拉取、清理、复位
│   │   ├── feeds.sh                  ← feeds 更新与安装
│   │   ├── network.sh                ← 网络操作辅助函数（git_retry, wget_retry）
│   │   ├── custom_feed.sh            ← 自定义 feed 软件包管理
│   │   ├── feed_source_fixes.sh      ← feed 源清理与替换
│   │   ├── package_source_updates.sh ← 软件包源码替换与补齐
│   │   ├── target_fixes.sh           ← 目标平台、内核、基础系统修正
│   │   ├── luci_fixes.sh             ← Luci 界面修正
│   │   ├── service_fixes.sh          ← 服务包与运行时配置修正
│   │   ├── docker.sh                 ← Docker 相关配置
│   │   ├── cups.sh                   ← CUPS 打印服务
│   │   ├── verify.sh                 ← 自定义 feed 安装路径验证
│   │   ├── general.sh                ← 兼容入口 → 重定向到 repo.sh
│   │   ├── packages.sh               ← 兼容入口 → 重定向到各子模块
│   │   ├── glibc_compat.sh           ← ⭐ glibc 运行时兼容层
│   ├── patches/                      ← 补丁和脚本
│   │   ├── 990_set_argon_primary     ← 设置 Argon 默认主题
│   │   ├── 991_custom_settings       ← 自定义系统设置
│   │   ├── 992_set-wifi-uci.sh       ← WiFi UCI 默认配置
│   │   ├── glibc-compat-check.sh    ← ⭐ glibc 兼容性诊断脚本
│   │   ├── tempinfo                  ← 温度信息脚本
│   │   ├── cpuusage                  ← CPU 使用率脚本
│   │   ├── hnatusage                 ← 硬件 NAT 状态脚本
│   │   ├── nss_diag.sh              ← NSS 诊断脚本
│   │   ├── pbr.user.cmcc / cmcc6     ← PBR 移动运营商路由
│   │   └── smp_affinity              ← SMP 亲和性配置
│   └── prebuilt_packages/            ← ⭐ 预编译包（本地定制）
│       ├── install.sh
│       ├── qbittorrent.conf
│       ├── lucky_2.27.2_Linux_arm64_wanji.tar.gz
│       └── lucky_2.27.2_Linux_x86_64_wanji.tar.gz
├── docs/                             ← ⭐ 本文档目录（本地定制）
│   ├── CHANGES.md                    ← 本地定制更改概览
│   ├── GLIBC_COMPAT.md               ← glibc 兼容层说明
│   └── MAINTENANCE.md                ← 本文档
```

## 构建阶段流程

`update.sh` 定义的 7 个阶段：

```
stage_repo_checkout           → clone_repo → clean_up → reset_feeds_conf
        │
stage_upstream_feeds_update  → update_feeds
        │
stage_feed_source_cleanup    → remove_unwanted_packages → remove_tweaked_packages
        │
stage_custom_feed_prepare    → install_custom_feed
        │
stage_pre_install_source_fixes → 各种源码修正
        │
stage_feeds_install          → install_feeds
        │
stage_post_install_package_fixes → 已安装包的修正 + 验证
```

**重要**: 阶段顺序不可调整，feeds install 前后依赖的目录结构不同。

## 同步上游

### 首次配置上游远程

```bash
git remote add upstream https://github.com/ZqinKing/wrt_release.git
```

### 定期同步

```bash
# 1. 获取上游最新代码
git fetch upstream

# 2. 查看差异
git log --oneline --left-right main...upstream/main

# 3. 合并上游（保留本地定制）
git merge upstream/main --no-ff

# 4. 解决冲突（如果有）
# 常见冲突区域：
#   - compile_base.config（上游可能删除，本地有定制）
#   - build_wrt.yml（编译目标、步骤差异）
#   - patches/ 目录（上游可能重构）

# 5. 推送
git push origin main
```

### 冲突处理指南

| 文件 | 可能冲突原因 | 处理策略 |
|------|-------------|---------|
| `compile_base.config` | 上游删除/修改 | 保留本地定制内容，吸收上游新增 |
| `build_wrt.yml` | 编译目标、步骤差异 | 保留本地编译目标和额外步骤 |
| `update.sh` | 模块结构变化 | 保留本地定制模块引用 |
| `patches/` 目录 | 上游重构 | 检查本地补丁是否仍需保留 |
| `glibc-compat-check.sh` | 上游不存在 | 运行诊断脚本，确认文件存在 |
| `modules/glibc_compat.sh` | 上游不存在 | 运行时 glibc 兼容层，确认 `update.sh` 中引用完好 |

### 合并后检查清单

- [ ] `lan_addr` 是否仍为 `192.168.199.1`
- [ ] 编译目标是否正确（仅编译亚瑟）
- [ ] `prebuilt_packages/` 是否仍然存在
- [ ] `glibc-compat-check.sh` 是否存在
- [ ] `modules/glibc_compat.sh` 是否在 `update.sh` 中正确引用
- [ ] `update_hdsentinel()` 输出路径是否为 `BUILD_DIR/files/bin/`
- [ ] 启用了 `GLIBC_COMPAT` 的设备 INI 是否正确
- [ ] `docs/` 目录是否完整
- [ ] CI 工作流是否正常

## 添加新设备

1. 在 `wrt_core/compilecfg/` 创建 `<device>.ini`：
   ```ini
   REPO_URL=https://github.com/example/openwrt.git
   REPO_BRANCH=main
   CONFIG=target_subtarget
   ```
2. 在 `wrt_core/deconfig/` 创建 `<device>.config`（设备专属配置）
3. 可选：将通用配置加入 `compile_base.config`
4. 在 `README.md` 设备列表中添加新条目

## 添加新软件包

1. 如果包来自自定义 feed → 修改 `wrt_core/modules/feed_source_fixes.sh` 或 `custom_feed.sh`
2. 如果包来自上游 feeds → 在设备 `.config` 中添加 `CONFIG_PACKAGE_<pkg>=y`
3. 如果需要源码级修正 → 在 `package_source_updates.sh` 或 `target_fixes.sh` 添加函数，并在 `update.sh` 中注册

## 本地定制文件标记

为便于维护，本地新增的文件建议在文件头添加注释标记：

```bash
# ⭐ 本地定制：说明此文件相对于上游的用途
```

已在以下文件中使用此标记：
- `wrt_core/deconfig/glibc.config`
- `wrt_core/patches/glibc-compat-check.sh`
- `wrt_core/prebuilt_packages/install.sh`
- `wrt_core/prebuilt_packages/qbittorrent.conf`
- `docs/` 目录下所有文件

---

## AI 维护指引

### 通用原则

1. **保持克制**：只修改你被明确要求修改的内容，不擅自重构、重命名或删除他人代码。
2. **先读后写**：修改任何文件前，先完整阅读该文件及相关模块，理解上下文后再动手。
3. **问清再动**：遇到不确定的意图或缺失的上下文时，先向用户提问，不猜测。
4. **保留标记**：本地定制的文件必须保留 `⭐ 本地定制` 注释标记。
5. **保持文档同步**：每次代码变更后，同步更新 `docs/` 下对应文档。

### 代码修改规范

#### 新增模块

在 `wrt_core/modules/` 下新增 `.sh` 文件时：

- 文件头必须包含功能说明和作者标记
- 导出函数的命名必须与模块职责一致
- 必须在 `update.sh` 中 `source` 加载
- 必须在对应构建阶段注册调用
- 必须在 `docs/MAINTENANCE.md` 的仓库结构图中添加条目
- 如属于本地定制，添加 `⭐ 本地定制` 标记

**模板**：

```bash
#!/usr/bin/env bash
# ⭐ 本地定制：模块功能简述
#
# 此模块负责处理 XXX，包括：
#   1. 功能 A
#   2. 功能 B
#
# 依赖：network.sh（wget_retry）
# 调用位置：update.sh → stage_pre_install_source_fixes
```

#### 修改已有模块

- 修改前先完整阅读该文件
- 修改后检查调用者是否受影响
- 如新增函数在 `update.sh` 中注册，注意阶段顺序约束
- 不得破坏模块的幂等性（多次运行结果一致）

#### 配置文件修改

- `compile_base.config`：所有设备共享的基础配置
- `<device>.config`：设备专属配置，覆盖基础配置
- 新增配置项需注明分类注释（如 `# Network`、`# USB Support`）

### 文档要求

#### 必须更新的文档场景

| 场景 | 需更新文档 |
|------|-----------|
| 新增模块/文件 | `docs/MAINTENANCE.md`（仓库结构图）、`docs/CHANGES.md`（更改清单） |
| 新增功能特性 | `docs/CHANGES.md`（更改清单）、如需要则创建独立文档 |
| 修改构建流程 | `docs/MAINTENANCE.md`（阶段流程图） |
| 同步上游 | `docs/CHANGES.md`（更新差异清单、最后更新日期） |
| 修复 Bug | `docs/CHANGES.md`（更改清单中添加条目） |

#### 文档格式要求

- 使用标准 Markdown，代码块标注语言
- 表格必须包含表头，对齐清晰
- 复杂功能需配图说明（ASCII 流程图或文字描述）
- 每个文档必须包含 `最后更新` 日期
- 引用外部资源需附完整 URL
- 中英文混排时，中英文之间加空格

#### 文档质量检查

- [ ] 文档日期已更新
- [ ] 功能描述准确、无歧义
- [ ] 示例命令可执行、已验证
- [ ] 文件间的交叉引用链接正确
- [ ] 无陈旧/冲突信息

### AI 工作流程

#### 第 1 步：理解上下文

```bash
# 必须执行的检查
git log --oneline -5          # 了解近期提交
git status --short            # 了解工作区状态
git diff --stat               # 了解未暂存变更范围
```

#### 第 2 步：阅读相关文档

```bash
# 必须阅读的文档
cat docs/CHANGES.md           # 了解本地定制范围
cat docs/MAINTENANCE.md       # 了解项目结构和规则
```

#### 第 3 步：编写代码

- 小步提交，每个提交聚焦一个逻辑变更
- 提交信息使用中文或英文，保持与项目历史一致
- 涉及本地定制的内容在提交信息中标注 `[local]` 前缀

#### 第 4 步：更新文档

- 所有功能变更必须同步更新文档
- 最后更新日期改为当天

#### 第 5 步：验证

```bash
# 最基本的验证
git diff --stat               # 确认变更范围符合预期
# 检查语法（如果是 shell 脚本）
bash -n <file>.sh
```

### 常见陷阱

1. **`update.sh` 阶段顺序**：`stage_pre_install_source_fixes` 和 `stage_post_install_package_fixes` 的目录状态完全不同，不要放错函数的调用位置。
2. **`git_retry` / `wget_retry`**：所有网络操作必须使用这两个辅助函数，不要直接调用 `git clone` 或 `wget`。
3. **`custom_feed` 路径**：`get_custom_feed_package_dir()` 返回 `package/feeds/custom_feed/`，这个目录在 feeds install 之后才存在。
4. **本地定制 vs 上游同步**：合并上游后，务必运行合并后检查清单，确保本地定制未被覆盖。
