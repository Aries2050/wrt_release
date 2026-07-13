# glibc 兼容层

> **最后更新**: 2026-07-14

## 背景

ImmortalWRT / OpenWRT 默认使用 **musl libc** 作为 C 标准库实现。许多第三方二进制工具（如 HDSentinel、某些 VPN 客户端、网卡驱动工具等）是 **glibc 动态链接**的，无法直接在 musl 系统上运行。

本模块在固件中捆绑 glibc 运行时库，并提供 `glibc-run` 包装脚本，使 glibc 二进制可以在 musl 系统上执行。

## 架构

```
固件中的文件布局:

/lib/glibc-aarch64/
├── ld-linux-aarch64.so.1     ← glibc 动态链接器 (符号链接)
├── libc.so.6                  ← glibc 核心库
├── libgcc_s.so.1              ← GCC 运行时库
├── libstdc++.so.6             ← C++ 标准库
└── ...                         ← 其他符号链接

/usr/bin/glibc-run             ← 包装脚本 (可执行)
/etc/init.d/glibc-compat       ← 启动验证服务
```

## 使用方法

在路由器上运行 glibc 动态链接的二进制：

```bash
# 基本用法
glibc-run /tmp/HDSentinel

# 带参数
glibc-run /tmp/HDSentinel /dev/sda

# 也可以直接指定完整路径
glibc-run /root/HDSentinel-armv8
```

## 工作原理

1. `glibc-run` 脚本找到捆绑的 glibc 动态链接器 `/lib/glibc-aarch64/ld-linux-aarch64.so.1`
2. 设置 `LD_LIBRARY_PATH` 优先搜索 `/lib/glibc-aarch64/` 下的 glibc 库
3. 通过 glibc 的 `ld-linux` 加载目标二进制及其所有依赖

这与 Linux 上的 `patchelf --set-interpreter` 或 `LD_PRELOAD` 思路类似，但更轻量、无需修改二进制本身。

## 构建时行为

模块 `wrt_core/modules/glibc_compat.sh` 在构建时：

1. **获取 glibc 库**: 从 Debian Trixie arm64 仓库下载 `libc6`、`libgcc-s1`、`libstdc++6` 的 `.deb` 包
2. **提取 .so 文件**: 解压 `.deb` 包，提取动态库文件
3. **安装到固件**: 将库文件放入 `package/base-files/files/lib/glibc-aarch64/`
4. **创建包装脚本**: 生成 `glibc-run` 到 `package/base-files/files/usr/bin/`
5. **创建 init 脚本**: 生成启动验证服务到 `package/base-files/files/etc/init.d/`

## 配置

可通过环境变量定制下载源：

```bash
# 使用国内镜像加速
DEBIAN_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/debian ./build.sh <device>

# 指定 Debian 版本（默认 trixie）
DEBIAN_RELEASE=bookworm ./build.sh <device>
```

## 验证

构建完成后可通过以下方式验证兼容层是否正常工作：

```bash
# 在构建机上检查打包的文件
ls -la <BUILD_DIR>/package/base-files/files/lib/glibc-aarch64/

# 刷写固件后在路由器上检查
glibc-run --help
ls /lib/glibc-aarch64/
```

## 注意事项

- 兼容层约增加 **5~10 MB** 固件体积
- 仅支持 **aarch64** 架构设备
- glibc 二进制性能与原生 musl 可能有细微差异
- 部分深度依赖内核特定行为的程序可能仍无法运行
