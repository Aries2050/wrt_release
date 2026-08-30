#!/usr/bin/env bash
# 上游源码拉取、清理和复位。

clone_repo() {
    if [[ ! -d $BUILD_DIR ]]; then
        echo "克隆仓库: $REPO_URL 分支: $REPO_BRANCH"
        if ! git_retry clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$BUILD_DIR"; then
            echo "错误：克隆仓库 $REPO_URL 失败" >&2
            exit 1
        fi
    fi
}


clean_up() {
    if [[ ! -d "$BUILD_DIR" ]]; then
        echo "Build directory $BUILD_DIR does not exist"
        return
    fi
    cd "$BUILD_DIR"
    if [[ -f ".config" ]]; then
        \rm -f ".config"
    fi
    if [[ -d "tmp" ]]; then
        \rm -rf "tmp"
    fi
    if [[ -d "logs" ]]; then
        \rm -rf "logs/*"
    fi
    if [[ -d "feeds" ]]; then
        ./scripts/feeds clean
    fi
    mkdir -p "tmp"
    echo "1" >"tmp/.build"
}


reset_feeds_conf() {
    # 所有源码修正都基于远端分支或指定提交的干净状态。
    git_retry reset --hard "origin/$REPO_BRANCH"
    git_retry clean -f -d
    git_retry pull
    if [[ $COMMIT_HASH != "none" ]]; then
        # ⭐ 本地定制：上游提交锁定（COMMIT_HASH）。
        # clone 为浅克隆（--depth 1），非 tip 的历史提交不在本地对象库，直接 checkout 会失败；
        # 先显式抓取该提交再检出（detached HEAD），保证锁定到任意历史提交都可靠。
        # 用于规避上游潜在破坏性改动；启用方式：设备 INI 设置 COMMIT_HASH=<完整提交哈希>，
        # 默认 none（不锁定）。切换锁定提交时 CI 缓存随 repo_flag 指纹自动失效。
        git_retry fetch --depth 1 origin "$COMMIT_HASH"
        git_retry checkout "$COMMIT_HASH"
        echo "已锁定源码到上游提交 $COMMIT_HASH（分支 $REPO_BRANCH）"
    fi
}
