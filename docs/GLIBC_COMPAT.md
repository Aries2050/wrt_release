# glibc 兼容层

> **最后更新**: 2026-07-17

## 方案说明

本仓库采用**运行时兼容层**的方式解决 glibc 二进制兼容问题，固件本身仍使用 **musl** 编译。

## 原理

通过在设备 INI 配置中设置 `GLIBC_COMPAT`，在 `update.sh` 阶段执行以下操作（未定义时默认启用）：

1. 从 Debian 仓库下载 glibc 运行时库（`libc6`、`libgcc-s1`、`libstdc++6`）
2. 解压至 `BUILD_DIR/files/lib/glibc-aarch64/`
3. 创建 `glibc-run` 包装脚本，通过 `ld-linux-aarch64.so.1` 加载 glibc 二进制
4. `BUILD_DIR/files/` 内容自动合并到固件根文件系统

### 实现细节

- **路径/配置延迟求值**：全局变量（如 `DEBIAN_MIRRORS`、`GLIBC_DIR`）改为 `_glibc_*()` 辅助函数内求值，避免 `source` 加载时变量未定义
- **Packages.gz 解析**：通过 `get_package_filename()` 从 Debian Packages.gz 获取包的 `Filename` 字段，而非按二进制名首字母猜测路径，解决 `libc6`→`glibc` 源码名不同导致的下载失败
- **白名单提取**：`extract_so_from_deb()` 采用 case 白名单模式，仅保留核心运行时库（`libc.so.*`、`libm.so.*`、`libpthread.so.*` 等），跳过非必需的 .so 文件
- **进程替代**：使用 `< <(find ... -print0)` 替代 `while read | pipe`，避免管道导致子 shell 中变量作用域丢失

### 运行时

glibc 链接的二进制通过 `glibc-run` 包装脚本运行：

```bash
glibc-run /bin/HDSentinel [参数...]
```

`glibc-run` 使用 glibc 的动态链接器（`ld-linux-aarch64.so.1`）和目标 glibc 运行时库加载二进制，与系统 musl 环境共存。

### 为何不采用系统级 LIBC 切换

上游 kconfig 的 LIBC choice 默认强制 musl，`make defconfig` 会自动重置 `CONFIG_LIBC`，且 `make` 内部也会重新运行 defconfig 覆盖手动修改。运行时兼容方案避免了与构建系统的对抗，实现更简单可靠。

## 启用方法

在 `wrt_core/compilecfg/<device>.ini` 中添加以下配置控制 glibc 兼容层（未定义时默认启用，设为 `false` 可禁用）：

```ini
GLIBC_COMPAT=true
```

目前已启用设备：**默认全部启用**，无需显式设置 `GLIBC_COMPAT=true`

正常编译即可，编译时日志中可看到 glibc 兼容层安装信息。

## 使用方式

### 运行 glibc 二进制

```bash
# HDSentinel
glibc-run /bin/HDSentinel /dev/sda

# 其他 glibc 程序
glibc-run /path/to/glibc-binary [参数...]
```

### 诊断检查

```bash
# 检查系统 glibc 状态
wrt_core/prebuilt_packages/install.sh check-glibc

# 分析指定二进制
wrt_core/prebuilt_packages/install.sh check-glibc /path/to/binary
```

或直接运行诊断脚本：

```bash
sh wrt_core/patches/glibc-compat-check.sh
sh wrt_core/patches/glibc-compat-check.sh /tmp/HDSentinel
```

### glibc-run 包装脚本

固件内置了 `glibc-run` 命令：

```
用法: glibc-run <二进制路径> [参数...]

示例:
  glibc-run /bin/HDSentinel
  glibc-run /bin/HDSentinel /dev/sda
```

## 文件清单

| 文件 | 作用 | 关键函数 |
|------|------|----------|
| `wrt_core/modules/glibc_compat.sh` | 核心实现：下载、解压、安装 glibc 运行时库 | `setup_glibc_compat()` — 入口；`get_package_version()` — 查询版本；`get_package_filename()` — 从 Packages.gz 解析包路径；`download_deb_package()` — 下载 .deb；`extract_so_from_deb()` — 白名单提取 .so |
| `wrt_core/modules/target_fixes.sh` | 下载 HDSentinel 到 `BUILD_DIR/files/bin/` | — |
| `wrt_core/patches/glibc-compat-check.sh` | 运行时诊断脚本 | — |
| `wrt_core/prebuilt_packages/install.sh` | 部署 HDSentinel 和检查兼容性 | — |
| `wrt_core/compilecfg/<device>.ini` | 设备配置，`GLIBC_COMPAT` 控制（默认 true） | — |
| `wrt_core/prebuilt_packages/hdsentinel/*.zip` | 离线回退包（网络不可用时使用） | — |

> **路径辅助函数**：`_glibc_mirrors()`、`_glibc_release()`、`_glibc_arch()`、`_glibc_dir()`、`_glibc_bundle()`、`_glibc_wrapper()`、`_glibc_init_scr()` 用于延迟求值路径和配置，避免模块 source 时全局变量未定义。

## 注意事项

- 未定义 `GLIBC_COMPAT` 时默认启用（true），设为 `false` 可跳过 glibc 兼容层注入
- glibc 固件比纯 musl 固件大约 **5~10 MB**
- 部分 musl 优化的包可能不能正常工作，但主流 OpenWRT 包均兼容 glibc
- 建议在需要运行第三方 glibc 二进制时开启，否则保持 musl 以获得更小体积
