#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""检测 OpenWrt/ImmortalWRT 构建树的包文件属主冲突（APK 语义）。

背景
----
APK 在「make package/install」（rootfs 组装）阶段才对文件属主做严格检查：
    ERROR: <pkgA>-<ver>: trying to overwrite <path> owned by <pkgB>-<ver>.
此时全部包已编译完成（本仓库约 2.5 小时），且 apk 遇到第一个冲突即中止。
本脚本在编译完成后、rootfs 组装前（build.sh 已拆分为 package/compile →
本检查 → 剩余阶段），或对任意已编译树直接扫描 .pkgdir 文件树，
一次列出全部「跨源码包」冲突，判定语义与 apk 一致：

* 同 origin（Source 源码包）之间的文件覆盖 → apk 允许静默覆盖，不算冲突；
* 不同 origin 之间的文件覆盖 → apk 报 files conflict（trying to overwrite）。

依据：编译期每个包生成 build_dir/target-*/<来源>/.pkgdir/<二进制包>/ 安装树，
以及 staging_dir/target-*/pkginfo/<二进制包>.control（含 Source 字段，即 apk origin）。

用法
----
    python3 scripts/check_pkg_conflicts.py --build-dir <构建树> [--quiet]

退出码：0 = 无冲突；1 = 存在冲突；2 = 参数/路径错误。
"""
import argparse
import glob
import os
import sys


def _norm(path):
    return path.replace(os.sep, "/")


def iter_claimed_paths(pkgdir):
    """遍历 .pkgdir/<bin>/ 安装树，产出安装路径（普通文件与目录符号链接）。"""
    for root, dirs, files in os.walk(pkgdir, followlinks=False):
        for name in files:
            yield _norm(os.path.relpath(os.path.join(root, name), pkgdir))
        # os.walk 不会进入目录符号链接，需单独捕获其路径本身（作为占位）
        for name in list(dirs):
            p = os.path.join(root, name)
            if os.path.islink(p):
                yield _norm(os.path.relpath(p, pkgdir))


def find_origin(staging_root, binpkg):
    """从 staging_dir/target-*/pkginfo/<binpkg>.control 读取 Source（apk origin）；
    缺失时回退为二进制包名本身（保守：视为独立 origin）。"""
    pattern = os.path.join(
        staging_root, "staging_dir", "target-*", "pkginfo", binpkg + ".control"
    )
    for control in sorted(glob.glob(pattern)):
        try:
            with open(control, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    if line.startswith("Source:"):
                        val = line.split(":", 1)[1].strip()
                        if val:
                            return val
        except OSError:
            continue
    return binpkg


def scan(build_dir):
    """返回 (冲突列表, 二进制包总数)。冲突格式：[(path, {origin: [bins]})]"""
    build_root = os.path.join(build_dir, "build_dir")
    file_origins = {}  # path -> {origin: set(bins)}
    pkg_count = 0

    targets = [
        d
        for d in sorted(os.listdir(build_root))
        if d.startswith("target-") and os.path.isdir(os.path.join(build_root, d))
    ]

    for target in targets:
        troot = os.path.join(build_root, target)
        for dirpath, dirnames, _ in os.walk(troot, followlinks=False):
            if os.path.basename(dirpath) != ".pkgdir":
                continue
            for binpkg in dirnames:
                bpkg_dir = os.path.join(dirpath, binpkg)
                if not os.path.isdir(bpkg_dir) or os.path.islink(bpkg_dir):
                    continue
                origin = find_origin(build_dir, binpkg)
                pkg_count += 1
                for rel in iter_claimed_paths(bpkg_dir):
                    rec = file_origins.setdefault(rel, {})
                    rec.setdefault(origin, set()).add(binpkg)
            dirnames[:] = []  # .pkgdir 内部不再下钻

    conflicts = []
    for path in sorted(file_origins):
        origins = file_origins[path]
        if len(origins) > 1:
            conflicts.append((path, origins))
    return conflicts, pkg_count


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="OpenWrt 构建树包文件属主冲突检测（APK 语义，预 rootfs 组装）"
    )
    ap.add_argument(
        "--build-dir",
        default="action_build",
        help="构建树根目录（含 build_dir/ 与 staging_dir/），默认 action_build",
    )
    ap.add_argument("--quiet", action="store_true", help="仅输出冲突清单")
    args = ap.parse_args(argv)

    if not os.path.isdir(os.path.join(args.build_dir, "build_dir")):
        print("错误：未找到构建树 %s（缺少 build_dir/）" % args.build_dir, file=sys.stderr)
        return 2

    conflicts, pkg_count = scan(os.path.abspath(args.build_dir))
    if not conflicts:
        if not args.quiet:
            print("OK：未发现包文件属主冲突（共扫描 %d 个二进制包）" % pkg_count)
        return 0

    if not args.quiet:
        print("发现 %d 个跨源码包文件属主冲突（APK 将报 trying to overwrite）：" % len(conflicts))
        print()
    for path, origins in conflicts:
        print("[冲突] %s" % path)
        for origin in sorted(origins):
            bins = ", ".join(sorted(origins[origin]))
            print("    origin=%s  二进制包: %s" % (origin, bins))
    if not args.quiet:
        print()
        print("提示：同 origin（源码包）内覆盖属 apk 允许的静默行为；")
        print("跨 origin 需移除一侧安装（参考 custom_feed.sh 中 *_conflict 处理函数）。")
    return 1


if __name__ == "__main__":
    sys.exit(main())