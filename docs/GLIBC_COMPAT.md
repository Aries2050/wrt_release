# glibc 兼容层

> **最后更新**: 2026-07-14

## 方案说明

本仓库采用**系统级切换 libc** 的方式解决 glibc 二进制兼容问题，而不是在 musl 上搭兼容层。

## 原理

通过在设备 INI 配置中设置 `GLIBC_COMPAT=true`，编译时自动将系统 libc 从 **musl** 切换为 **glibc**（`CONFIG_LIBC="glibc"`）。

- 整个固件使用 glibc 编译
- 所有标准 glibc 动态链接的二进制（如 HDSentinel）**原生运行**，无需任何包装脚本
- 固件体积略有增加，但兼容性最佳

## 启用方法

### 1. 为设备启用

编辑 `wrt_core/compilecfg/<device>.ini`，添加：

```ini
GLIBC_COMPAT=true
```

目前已启用设备：**全部 18 个设备均已启用**

### 2. 编译

正常编译即可：

```bash
./build.sh link_nn6000v2_immwrt
```

## 使用方式

### 运行 glibc 二进制

固件使用 glibc 编译，所有标准 Linux 二进制可直接运行：

```bash
# HDSentinel 直接可运行
/root/HDSentinel-armv8

# 或通过部署脚本
wrt_core/prebuilt_packages/install.sh deploy-hdsentinel
```

### 诊断检查

检查系统 glibc 兼容性和分析 ELF 二进制：

```bash
# 检查系统 glibc 状态
wrt_core/prebuilt_packages/install.sh check-glibc

# 分析指定二进制
wrt_core/prebuilt_packages/install.sh check-glibc /path/to/binary
```

或直接运行诊断脚本：

```bash
sh wrt_core/patches/glibc-compat-check.sh
sh wrt_core/patches/glibc-compat-check.sh /tmp/HDSentinel-armv8
```

## 文件清单

| 文件 | 作用 |
|------|------|
| `wrt_core/deconfig/glibc.config` | 配置片段：切换系统 libc 为 glibc |
| `wrt_core/patches/glibc-compat-check.sh` | 运行时诊断脚本 |
| `wrt_core/prebuilt_packages/install.sh` | 部署 HDSentinel 和检查兼容性 |
| `wrt_core/compilecfg/<device>.ini` | 设备配置，`GLIBC_COMPAT=true` 触发切换 |

## 注意事项

- 仅在 `GLIBC_COMPAT=true` 标记的设备上启用
- glibc 固件比 musl 固件大约 **5~10 MB**
- 部分 musl 优化的包可能不能正常工作，但主流 OpenWRT 包均兼容 glibc
- 建议在需要运行第三方 glibc 二进制时开启，否则保持 musl 以获得更小体积
