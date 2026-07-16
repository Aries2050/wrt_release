# glibc 兼容层

> **最后更新**: 2026-07-17

## 方案说明

本仓库采用**运行时兼容层**的方式解决 glibc 二进制兼容问题，固件本身仍使用 **musl** 编译。

## 原理

通过在设备 INI 配置中设置 `GLIBC_COMPAT=true`，在 `update.sh` 阶段执行以下操作：

1. 从 Debian 仓库下载 glibc 运行时库（`libc6`、`libgcc-s1`、`libstdc++6`）
2. 解压至 `BUILD_DIR/files/lib/glibc-aarch64/`
3. 创建 `glibc-run` 包装脚本，通过 `ld-linux-aarch64.so.1` 加载 glibc 二进制
4. `BUILD_DIR/files/` 内容自动合并到固件根文件系统

### 运行时

glibc 链接的二进制通过 `glibc-run` 包装脚本运行：

```bash
glibc-run /bin/HDSentinel [参数...]
```

`glibc-run` 使用 glibc 的动态链接器（`ld-linux-aarch64.so.1`）和目标 glibc 运行时库加载二进制，与系统 musl 环境共存。

### 为何不采用系统级 LIBC 切换

上游 kconfig 的 LIBC choice 默认强制 musl，`make defconfig` 会自动重置 `CONFIG_LIBC`，且 `make` 内部也会重新运行 defconfig 覆盖手动修改。运行时兼容方案避免了与构建系统的对抗，实现更简单可靠。

## 启用方法

编辑 `wrt_core/compilecfg/<device>.ini`，添加：

```ini
GLIBC_COMPAT=true
```

目前已启用设备：**全部 18 个设备均已启用**

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

| 文件 | 作用 |
|------|------|
| `wrt_core/modules/glibc_compat.sh` | 核心实现：下载、解压、安装 glibc 运行时库 |
| `wrt_core/modules/target_fixes.sh` | 下载 HDSentinel 到 `BUILD_DIR/files/bin/` |
| `wrt_core/patches/glibc-compat-check.sh` | 运行时诊断脚本 |
| `wrt_core/prebuilt_packages/install.sh` | 部署 HDSentinel 和检查兼容性 |
| `wrt_core/compilecfg/<device>.ini` | 设备配置，`GLIBC_COMPAT=true` 触发 |
| `wrt_core/prebuilt_packages/hdsentinel/*.zip` | 离线回退包（网络不可用时使用） |

## 注意事项

- 仅在 `GLIBC_COMPAT=true` 标记的设备上启用
- glibc 固件比 musl 固件大约 **5~10 MB**
- 部分 musl 优化的包可能不能正常工作，但主流 OpenWRT 包均兼容 glibc
- 建议在需要运行第三方 glibc 二进制时开启，否则保持 musl 以获得更小体积
