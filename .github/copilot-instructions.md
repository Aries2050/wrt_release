# Copilot 指令：wrt_release

本仓库是一个 OpenWrt / ImmortalWRT 路由器固件构建仓库（本地定制版），源自 `ZqinKing/wrt_release`。

## 核心规范

1. **文档同步**：每次代码变更后，必须同步更新 `docs/CHANGES.md`（修订时间线 + 定制清单），并更新文件顶部 `最后更新` 日期。
2. **CHANGES.md 提交列规范**：
   - 提交列填写**实际提交哈希**（`` `7位哈希` ``）或 **`当前提交`**（仅限尚未提交的最新改动）。
   - **禁止**用描述性文字（如 `LED 服务修复`）作为提交列。
   - **下一次修改仓库时**，必须把上一次遗留的 `当前提交` 占位回填为实际哈希（用 `git log -1 --format="%h"` 查询）。
   - 哈希必须真实存在（可用 `git rev-parse --verify <hash>^{commit}` 校验）。
3. **本地定制标记**：本地新增或修改的文件保留 `⭐ 本地定制` 注释标记。
4. **保持克制**：只修改被明确要求的内容，不擅自重构、重命名或删除。

## 构建与验证

- 主编译入口：`./build.sh <device> [debug|container|container_debug|config_preview]`
- 核心构建流程：`wrt_core/update.sh`（7 个阶段，顺序不可调整）
- 预编译包完整性检查：`python scripts/check_prebuilt.py`
- 修改 shell 脚本后建议用 `bash -n` 做语法检查

## 完整规范

- 维护指南：`docs/MAINTENANCE.md` —— 仓库结构、构建阶段流程、AI 维护指引、CHANGES.md 修订时间线规范（权威来源）
- 更改记录：`docs/CHANGES.md` —— 修订时间线 + 定制清单
- 提交记录规范如有冲突，以 `docs/MAINTENANCE.md` 为准
