#!/usr/bin/env bash
# glibc 兼容层 —— 在 musl 系统上为 glibc 动态链接的二进制提供运行环境。
#
# 原理：
#   1. 从 Debian aarch64 仓库下载 glibc 运行时库（libc6、libgcc-s1、libstdc++6）
#   2. 解压至固件 /lib/glibc-aarch64/ 目录
#   3. 提供 glibc-run 包装脚本，通过 ld-linux-aarch64.so.1 加载目标二进制
#
# 用法：
#   glibc-run /path/to/glibc-binary [args...]
#
# 仓库 URL（Debian 13 "Trixie"，aarch64 / arm64）：
# 镜像列表（按优先级尝试）
DEBIAN_MIRRORS=(
    "${DEBIAN_MIRROR:-https://ftp.debian.org/debian}"
    "https://deb.debian.org/debian"
    "https://mirrors.tuna.tsinghua.edu.cn/debian"
)
DEBIAN_RELEASE="${DEBIAN_RELEASE:-trixie}"
DEBIAN_ARCH="arm64"

GLIBC_DIR="lib/glibc-aarch64"
BUNDLE_DIR="$BUILD_DIR/files/$GLIBC_DIR"
WRAPPER_PATH="$BUILD_DIR/files/usr/bin/glibc-run"
INIT_SCRIPT_PATH="$BUILD_DIR/files/etc/init.d/glibc-compat"

# 需要下载的 Debian 软件包列表
GLIBC_DEB_PACKAGES=(
    "libc6"
    "libgcc-s1"
    "libstdc++6"
)

# ---------------------------------------------------------------
#  辅助函数
# ---------------------------------------------------------------

# 从 Debian 仓库下载指定架构和版本的 .deb 包
download_deb_package() {
    local pkg_name="$1"
    local pkg_ver="$2"
    local target_dir="$3"
    local prefix="${pkg_name:0:1}"

    for mirror in "${DEBIAN_MIRRORS[@]}"; do
        local deb_url="${mirror}/pool/main/${prefix}/${pkg_name}/${pkg_name}_${pkg_ver}_${DEBIAN_ARCH}.deb"
        echo "  尝试: ${deb_url}"
        if wget_retry -qO "$target_dir/${pkg_name}.deb" "$deb_url" 2>/dev/null; then
            echo "  成功下载: ${pkg_name}_${pkg_ver}_${DEBIAN_ARCH}.deb (来自 ${mirror})"
            return 0
        fi
    done

    echo "  警告: 所有镜像均无法下载 ${pkg_name}_${pkg_ver}_${DEBIAN_ARCH}.deb" >&2
    return 1
}

# 从 .deb 包中提取 .so 文件
extract_so_from_deb() {
    local deb_file="$1"
    local output_dir="$2"
    local tmp_dir
    local found=0

    tmp_dir=$(mktemp -d)

    # 解压 .deb (ar 归档) — 兼容不同版本 ar
    (cd "$tmp_dir" && ar -x "$deb_file") 2>/dev/null || {
        echo "  警告: 无法解压 $(basename "$deb_file")（ar 不可用？）" >&2
        rm -rf "$tmp_dir"
        return 1
    }

    # 解压 data.tar.* (可能是 .tar.xz, .tar.zst, .tar.gz)
    local data_tar
    for data_tar in "$tmp_dir/data.tar."*; do
        if [ -f "$data_tar" ]; then
            tar -xf "$data_tar" -C "$tmp_dir" 2>/dev/null || true
        fi
    done

    # 查找并复制 .so 文件
    local so_files
    so_files=$(find "$tmp_dir" -name "*.so*" -type f 2>/dev/null || true)
    if [ -n "$so_files" ]; then
        echo "$so_files" | while read -r so_file; do
            # 只复制实际的 .so 库文件（跳过链接）
            if [ ! -L "$so_file" ]; then
                local basename
                basename=$(basename "$so_file")
                \cp -f "$so_file" "$output_dir/$basename" 2>/dev/null || true
                echo "  提取: $basename"
                found=1
            fi
        done
    fi

    # 提取动态链接器 ld-linux-aarch64.so.1
    local ld_file
    ld_file=$(find "$tmp_dir" -name "ld-linux-aarch64*" -type f 2>/dev/null | head -1)
    if [ -n "$ld_file" ] && [ ! -L "$ld_file" ]; then
        \cp -f "$ld_file" "$output_dir/" 2>/dev/null || true
        echo "  提取: $(basename "$ld_file")"
        found=1
    fi

    # 创建必要的符号链接
    if [ -d "$tmp_dir/lib" ]; then
        find "$tmp_dir/lib" -maxdepth 1 -name "*.so*" -type l 2>/dev/null | while read -r link; do
            local link_target
            link_target=$(readlink "$link" 2>/dev/null || true)
            local link_name
            link_name=$(basename "$link")
            if [ -n "$link_target" ] && [ -f "$output_dir/$link_target" ]; then
                ln -sf "$link_target" "$output_dir/$link_name" 2>/dev/null || true
            fi
        done
    fi

    rm -rf "$tmp_dir"

    if [ "$found" -eq 0 ]; then
        echo "  警告: 在 $(basename "$deb_file") 中未找到任何 .so 文件" >&2
        return 1
    fi
    return 0
}

# 获取 Debian 软件包的最新版本号
get_package_version() {
    local pkg_name="$1"
    local tmp_pkg

    tmp_pkg=$(mktemp)

    for mirror in "${DEBIAN_MIRRORS[@]}"; do
        local packages_url="${mirror}/dists/${DEBIAN_RELEASE}/main/binary-${DEBIAN_ARCH}/Packages.gz"
        if wget_retry -qO- "$packages_url" 2>/dev/null | gunzip -c 2>/dev/null > "$tmp_pkg"; then
            local version
            version=$(awk -v pkg="$pkg_name" '
                /^Package: / { p = $2 }
                p == pkg && /^Version: / { print $2; exit }
            ' "$tmp_pkg")
            rm -f "$tmp_pkg"
            if [ -n "$version" ]; then
                echo "$version"
                return 0
            fi
        fi
    done

    rm -f "$tmp_pkg"
    echo "警告: 所有镜像均无法获取 ${pkg_name} 的版本信息" >&2
    return 1
}

# ---------------------------------------------------------------
#  主要功能函数
# ---------------------------------------------------------------

# 下载并安装 glibc 兼容库到固件
setup_glibc_compat() {
    local target_dir="$BUNDLE_DIR"
    local tmp_dl_dir
    local success_count=0
    local total_count=${#GLIBC_DEB_PACKAGES[@]}

    echo "=========================================="
    echo "  设置 glibc 兼容层 (aarch64)"
    echo "  镜像: ${DEBIAN_MIRRORS[*]}"
    echo "  发行版: ${DEBIAN_RELEASE}"
    echo "=========================================="

    # 创建目标目录
    mkdir -p "$target_dir"
    mkdir -p "$(dirname "$WRAPPER_PATH")"
    mkdir -p "$(dirname "$INIT_SCRIPT_PATH")"

    tmp_dl_dir=$(mktemp -d)

    for pkg in "${GLIBC_DEB_PACKAGES[@]}"; do
        echo "  [${pkg}] 查询版本..."
        local version
        version=$(get_package_version "$pkg") || true
        if [ -z "$version" ]; then
            echo "  [${pkg}] ⚠ 跳过（无法获取版本）"
            continue
        fi
        echo "  [${pkg}] 版本: ${version}"

        echo "  [${pkg}] 下载中..."
        if download_deb_package "$pkg" "$version" "$tmp_dl_dir"; then
            echo "  [${pkg}] 解压中..."
            if extract_so_from_deb "$tmp_dl_dir/${pkg}.deb" "$target_dir"; then
                echo "  [${pkg}] ✓ 安装成功"
                success_count=$((success_count + 1))
            else
                echo "  [${pkg}] ⚠ 解压失败" >&2
            fi
        else
            echo "  [${pkg}] ⚠ 下载失败" >&2
        fi
    done

    # 创建动态链接器符号链接
    local ld_file
    ld_file=$(find "$target_dir" -name "ld-linux-aarch64*" -type f 2>/dev/null | head -1)
    if [ -n "$ld_file" ]; then
        local ld_basename
        ld_basename=$(basename "$ld_file")
        ln -sf "$ld_basename" "$target_dir/ld-linux-aarch64.so.1" 2>/dev/null || true
        echo "动态链接器: $ld_basename"
    fi

    # 清理下载缓存
    rm -rf "$tmp_dl_dir"

    # 列出已安装的库
    echo "------------------------------------------"
    echo "结果: ${success_count}/${total_count} 个包安装成功"
    echo "已安装的 glibc 库:"
    if [ -d "$target_dir" ]; then
        ls -la "$target_dir" 2>/dev/null || echo "  (空)"
    else
        echo "  (目录不存在)"
    fi
    echo "=========================================="

    # 不要因为 glibc 兼容层失败而阻断整体构建
    if [ "$success_count" -eq 0 ]; then
        echo "⚠ 警告: glibc 兼容层未安装任何库，glibc-run 将不可用"
        echo "  可设置 DEBIAN_MIRROR 环境变量指定可用的镜像源"
    fi
}

# 创建 glibc-run 包装脚本
install_glibc_run_wrapper() {
    mkdir -p "$(dirname "$WRAPPER_PATH")"

    cat <<'GLIBC_WRAPPER' > "$WRAPPER_PATH"
#!/bin/sh
# glibc-run — 使用捆绑的 glibc 加载器运行 glibc 动态链接的二进制文件
#
# 用法: glibc-run <二进制路径> [参数...]
#
# 示例:
#   glibc-run /tmp/HDSentinel
#   glibc-run /tmp/HDSentinel /dev/sda

GLIBC_DIR="/lib/glibc-aarch64"
LOADER="$GLIBC_DIR/ld-linux-aarch64.so.1"

if [ ! -f "$LOADER" ]; then
    echo "错误: glibc 兼容层未安装 ($LOADER 不存在)" >&2
    echo "请先安装 glibc 兼容层或检查固件版本" >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "用法: $0 <二进制路径> [参数...]" >&2
    exit 1
fi

BINARY="$1"
shift

if [ ! -f "$BINARY" ]; then
    echo "错误: 二进制文件 '$BINARY' 不存在" >&2
    exit 1
fi

if [ ! -x "$BINARY" ] && [ ! -f "$BINARY" ]; then
    echo "警告: '$BINARY' 没有执行权限，尝试继续..." >&2
fi

# 使用 glibc 的动态链接器加载二进制
# 设置 LD_LIBRARY_PATH 让 glibc 的库优先
export LD_LIBRARY_PATH="$GLIBC_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

exec "$LOADER" "$BINARY" "$@"
GLIBC_WRAPPER

    chmod +x "$WRAPPER_PATH"
    echo "已创建 glibc-run 包装脚本: $WRAPPER_PATH"
}

# 创建 glibc 兼容层初始化脚本（用于系统启动时验证）
install_glibc_init_script() {
    mkdir -p "$(dirname "$INIT_SCRIPT_PATH")"

    cat <<'GLIBC_INIT' > "$INIT_SCRIPT_PATH"
#!/bin/sh /etc/rc.common
# glibc 兼容层初始化
# 在系统启动时验证 glibc 环境是否就绪

START=10
STOP=10

boot() {
    # 验证 glibc 库完整性
    local GLIBC_DIR="/lib/glibc-aarch64"
    local LOADER="$GLIBC_DIR/ld-linux-aarch64.so.1"

    if [ -f "$LOADER" ] && [ -d "$GLIBC_DIR" ]; then
        logger -t glibc-compat "glibc 兼容层已就绪 ($(ls "$GLIBC_DIR"/*.so* 2>/dev/null | wc -l) 个库文件)"
    else
        logger -t glibc-compat "警告: glibc 兼容层未安装或损坏"
    fi
}

start() {
    boot
}

stop() {
    return 0
}
GLIBC_INIT

    chmod +x "$INIT_SCRIPT_PATH"
    echo "已创建 glibc 初始化脚本: $INIT_SCRIPT_PATH"
}

# 验证 glibc 兼容层是否已正确安装（仅警告，不阻断构建）
verify_glibc_compat() {
    local target_dir="$BUNDLE_DIR"
    local errors=0

    echo "正在验证 glibc 兼容层..."

    # 检查目录是否存在
    if [ ! -d "$target_dir" ]; then
        echo "⚠ 警告: glibc 兼容层目录不存在 ($target_dir)"
        echo "  固件将不包含 glibc 兼容层，glibc-run 不可用"
        return 0
    fi

    # 检查动态链接器
    if [ -z "$(find "$target_dir" -name "ld-linux-aarch64*" -type f 2>/dev/null | head -1)" ]; then
        echo "⚠ 警告: 动态链接器 (ld-linux-aarch64*) 未找到"
        echo "  glibc 兼容层可能未正确安装，但不影响固件构建"
        errors=$((errors + 1))
    fi

    # 检查 libc.so
    if [ -z "$(find "$target_dir" -name "libc.so*" -type f 2>/dev/null | head -1)" ]; then
        echo "⚠ 警告: libc.so 未找到"
        errors=$((errors + 1))
    fi

    # 检查包装脚本
    if [ ! -f "$WRAPPER_PATH" ]; then
        echo "⚠ 警告: glibc-run 包装脚本未安装"
        errors=$((errors + 1))
    fi

    if [ $errors -eq 0 ]; then
        echo "glibc 兼容层验证通过 ✓"
    else
        echo "glibc 兼容层发现 $errors 个问题（不影响固件构建）"
    fi

    # 始终返回 0，不阻断构建流程
    return 0
}
