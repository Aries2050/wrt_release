#!/usr/bin/env bash

# Determine wrt_core path
if [ -d "wrt_core" ]; then
    WRT_CORE_PATH="wrt_core"
elif [ -d "../wrt_core" ]; then
    WRT_CORE_PATH="../wrt_core"
else
    # Fallback to script directory if wrt_core is current dir or relative
    WRT_CORE_PATH=$(dirname "$0")
fi

BASE_PATH=$(cd "$WRT_CORE_PATH" && pwd)

source "$BASE_PATH/modules/network.sh"

Dev=$1

INI_FILE="$BASE_PATH/compilecfg/$Dev.ini"

if [[ ! -f $INI_FILE ]]; then
    echo "INI file not found: $INI_FILE"
    exit 1
fi

read_ini_by_key() {
    local key=$1
    awk -F"=" -v key="$key" '$1 == key {gsub(/\r/,"",$2); print $2}' "$INI_FILE"
}

REPO_URL=$(read_ini_by_key "REPO_URL")
REPO_BRANCH=$(read_ini_by_key "REPO_BRANCH")
REPO_BRANCH=${REPO_BRANCH:-main}
COMMIT_HASH=$(read_ini_by_key "COMMIT_HASH")
COMMIT_HASH=${COMMIT_HASH:-none}
# GitHub Actions usually runs in root of repo, so build dir should be relative to repo root
# We need to construct absolute path or ensure context is correct.
# Assuming this script is run from repo root or wrt_core.
# Let's use relative path "action_build" next to wrt_core if possible or just use what works.
# Original script used BASE_PATH/action_build.
BUILD_DIR="$BASE_PATH/../action_build"

echo $REPO_URL $REPO_BRANCH
# ⭐ 本地定制：repo_flag 是 CI 缓存键的一部分（cache key 的源码身份指纹）。
# 上游提交锁定（COMMIT_HASH）一并纳入：切换锁定提交时缓存键随之变化，
# 避免误用其它提交产物缓存。默认 none（不锁定）时保持原格式不变。
if [[ $COMMIT_HASH != "none" ]]; then
    echo "$REPO_URL/$REPO_BRANCH@$COMMIT_HASH" >"$BASE_PATH/../repo_flag"
else
    echo "$REPO_URL/$REPO_BRANCH" >"$BASE_PATH/../repo_flag"
fi

# 写入配置指纹，用于缓存 key 检测配置变更
GLIBC_COMPAT=$(read_ini_by_key "GLIBC_COMPAT")
CONFIG_FRAGMENTS=$(read_ini_by_key "CONFIG_FRAGMENTS")
echo "${Dev}:GLIBC_COMPAT=${GLIBC_COMPAT}:FRAGMENTS=${CONFIG_FRAGMENTS}" >"$BASE_PATH/../config_flag"

git_retry clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$BUILD_DIR"

# GitHub Action 移除国内下载源
PROJECT_MIRRORS_FILE="$BUILD_DIR/scripts/projectsmirrors.json"

if [ -f "$PROJECT_MIRRORS_FILE" ]; then
    sed -i '/.cn\//d; /tencent/d; /aliyun/d' "$PROJECT_MIRRORS_FILE"
fi
