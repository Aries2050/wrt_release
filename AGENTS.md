# AGENTS.md

本仓库是一个 OpenWrt / ImmortalWRT 路由器固件构建仓库（本地定制版）。

## 核心规则（AI 必须遵守）

1. **文档同步**：每次代码变更后，同步更新 `docs/CHANGES.md`（修订时间线 + 定制清单），并更新文件顶部 `最后更新` 日期。
2. **CHANGES.md 提交列规范**：
   - 提交列写实际提交哈希（`` `7位哈希` ``）或 `当前提交`（仅限未提交的最新改动）。
   - 禁止描述性文字（如 `LED 服务修复`）。
   - 下一次修改仓库时，把上次遗留的 `当前提交` 回填为实际哈希（`git log -1 --format="%h"` 查询）。
   - 哈希用 `git rev-parse --verify <hash>^{commit}` 校验。
3. **本地定制标记**：本地新增/修改的文件保留 `⭐ 本地定制` 注释。
4. **保持克制**：只修改被明确要求的内容，不擅自重构、重命名或删除。

## 构建与验证

- 入口：`./build.sh <device> [debug|container|container_debug|config_preview]`
- 流程：`wrt_core/update.sh`（7 阶段，顺序不可调整）
- 检查：`python scripts/check_prebuilt.py`；shell 脚本用 `bash -n`

## 完整规范

- `.github/copilot-instructions.md` —— Copilot 指令（本文件同源）
- `docs/MAINTENANCE.md` —— 维护指南（仓库结构、AI 维护指引、修订时间线规范，权威来源）
- `docs/CHANGES.md` —— 更改记录
