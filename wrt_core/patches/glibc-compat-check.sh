#!/bin/sh
# ⭐ 本地定制：glibc-compat-check - 检查 glibc 兼容层状态并修复二进制程序
# 用法: glibc-compat-check [二进制文件...]
#       不加参数时仅检查系统状态

GLIBC_LINKER="/lib/ld-linux-aarch64.so.1"
GLIBC_LINKER_ARM="/lib/ld-linux-armhf.so.3"
MUSL_LINKER="/lib/ld-musl-aarch64.so.1"

echo "=========================================="
echo " glibc 兼容层检查"
echo "=========================================="

# 检查动态链接器
check_linker() {
    local linker="$1"
    local arch="$2"
    if [ -f "$linker" ]; then
        echo "  ✅ $arch 动态链接器: $linker (存在)"
        return 0
    else
        echo "  ❌ $arch 动态链接器: $linker (不存在)"
        return 1
    fi
}

check_linker "$GLIBC_LINKER" "aarch64"
check_linker "$GLIBC_LINKER_ARM" "ARM 32-bit"

echo ""
echo "系统 C 库:"
if [ -f "$MUSL_LINKER" ]; then
    MUSL_TARGET=$(readlink "$MUSL_LINKER" 2>/dev/null || echo "$MUSL_LINKER")
    echo "  musl: $MUSL_TARGET"
fi

# 检查关键 glibc 库
echo ""
echo "关键 glibc 库:"
for lib in libc.so.6 libm.so.6 libpthread.so.0 librt.so.1 libdl.so.2; do
    found=$(find /lib /usr/lib -name "$lib" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "  ✅ $lib → $found"
    else
        echo "  ❌ $lib (未找到)"
    fi
done

# 分析指定的二进制文件
if [ $# -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo " 二进制文件兼容性分析"
    echo "=========================================="
    for binary in "$@"; do
        if [ ! -f "$binary" ]; then
            echo "  ❌ 文件不存在: $binary"
            continue
        fi

        echo ""
        echo "文件: $binary ($(ls -lh "$binary" | awk '{print $5}'))"

        # 检查 ELF 头
        magic=$(dd if="$binary" bs=1 count=4 2>/dev/null | od -A x -t x1 2>/dev/null | head -1)
        if echo "$magic" | grep -q "7f 45 4c 46"; then
            echo "  ✅ ELF 格式正确"
        else
            echo "  ❌ 不是 ELF 格式"
            continue
        fi

        # 检查架构
        arch_byte=$(dd if="$binary" bs=1 skip=4 count=1 2>/dev/null | od -A n -t u1 2>/dev/null | tr -d ' ')
        case "$arch_byte" in
            1) echo "  架构: 32-bit" ;;
            2) echo "  架构: 64-bit ✅ (匹配 aarch64)" ;;
            *) echo "  架构: 未知 ($arch_byte)" ;;
        esac

        # 检查动态链接器路径
        interp=$(strings "$binary" 2>/dev/null | grep -E "^/lib/ld-linux|^/lib/ld-musl" | head -1)
        if [ -n "$interp" ]; then
            echo "  需要链接器: $interp"
            if [ -f "$interp" ]; then
                echo "  ✅ 链接器存在，可直接运行"
            elif [ -f "/lib/ld-linux-aarch64.so.1" ] && echo "$interp" | grep -q "ld-linux-aarch64"; then
                echo "  ✅ 链接器存在，可直接运行"
            else
                echo "  ❌ 链接器不存在，无法运行"
                echo "  提示: 启用 glibc 配置后重新编译固件"
            fi
        else
            echo "  类型: 静态链接 ✅"
        fi

        # 检查 glibc 库依赖
        missing_libs=""
        for lib_pattern in "libc\.so" "libm\.so" "libpthread\.so" "librt\.so"; do
            if strings "$binary" 2>/dev/null | grep -q "$lib_pattern"; then
                expected_lib=$(strings "$binary" 2>/dev/null | grep "$lib_pattern" | head -1)
                found_lib=$(find /lib /usr/lib -name "$expected_lib" -type f 2>/dev/null | head -1)
                if [ -z "$found_lib" ]; then
                    missing_libs="$missing_libs $expected_lib"
                fi
            fi
        done

        if [ -n "$missing_libs" ]; then
            echo "  缺失库: $missing_libs"
        fi
    done
fi

echo ""
echo "=========================================="
echo " 检查完成"
echo "=========================================="