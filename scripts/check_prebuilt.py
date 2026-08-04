# -*- coding: utf-8 -*-
"""检查 prebuilt_packages 预编译包的完整性。"""
import os, re, gzip, hashlib

ROOT = r"e:\Code\router\wrt_release"
wrt = os.path.join(ROOT, "wrt_core")
pre = os.path.join(wrt, "prebuilt_packages")
pkgs = os.path.join(pre, "pkgs")

print("=" * 72)
print("prebuilt_packages 完整性检查")
print("=" * 72)

# 1) pkgs 目录 IPK 文件 vs Packages 索引
print("\n[1] qBittorrent opkg 仓库 (pkgs/)")
ipk_files = {}
if os.path.isdir(pkgs):
    for f in os.listdir(pkgs):
        if f.endswith(".ipk"):
            ipk_files[f] = os.path.getsize(os.path.join(pkgs, f))

print(f"  目录中的 .ipk 文件: {len(ipk_files)}")
for f, s in sorted(ipk_files.items()):
    print(f"    {f}  ({s/1024:.1f} KB)")

# 解析 Packages 索引中的 Filename + SHA256
index_files = {}
index_path = os.path.join(pkgs, "Packages")
if os.path.exists(index_path):
    with open(index_path, encoding="utf-8", errors="replace") as fh:
        content = fh.read()
else:
    content = None
    gz = os.path.join(pkgs, "Packages.gz")
    if os.path.exists(gz):
        with gzip.open(gz, "rt", encoding="utf-8", errors="replace") as fh:
            content = fh.read()

if content:
    for blk in content.split("\n\n"):
        fn = re.search(r"^Filename:\s*(\S+)", blk, re.M)
        sh = re.search(r"^SHA256sum:\s*(\S+)", blk, re.M)
        sz = re.search(r"^Size:\s*(\S+)", blk, re.M)
        if fn:
            index_files[fn.group(1)] = (sh.group(1) if sh else None, int(sz.group(1)) if sz else None)

print(f"  索引 (Packages) 中记录的文件: {len(index_files)}")
for fn in sorted(index_files):
    present = "OK" if fn in ipk_files else "!! 缺失"
    print(f"    {fn:<55} {present}")
    if fn in ipk_files:
        sh, sz = index_files[fn]
        real = hashlib.sha256(open(os.path.join(pkgs, fn), "rb").read()).hexdigest()
        ok = "SHA256 匹配" if sh and real == sh else "!! SHA256 不匹配"
        if sh:
            print(f"        {ok}")

# 2) key 签名
print("\n[2] opkg 签名 key")
key_file = os.path.join(pre, "key", "527ca1333af7875e")
sig_file = os.path.join(pkgs, "Packages.sig")
print(f"  签名公钥 key/527ca1333af7875e : {'存在' if os.path.exists(key_file) else '!! 缺失'}")
print(f"  Packages.sig                  : {'存在' if os.path.exists(sig_file) else '!! 缺失'}")

# 3) lucky 版本
print("\n[3] lucky 预编译包")
lucky_archs = {}
for f in os.listdir(pre):
    m = re.match(r"lucky_([\d\.]+)_Linux_(arm64|x86_64)_wanji\.tar\.gz", f)
    if m:
        lucky_archs[m.group(2)] = (m.group(1), os.path.getsize(os.path.join(pre, f)) / 1024 / 1024)
for arch, (ver, mb) in sorted(lucky_archs.items()):
    print(f"  {arch:<8} v{ver:<10} {mb:.1f} MB")
missing_arch = {"arm64", "x86_64"} - set(lucky_archs)
if missing_arch:
    print(f"  !! 缺少架构: {missing_arch}")

# 4) HDSentinel
print("\n[4] HDSentinel 部署")
hd = os.path.join(pre, "hdsentinel")
print(f"  hdsentinel/ 目录: {os.listdir(hd) if os.path.isdir(hd) else '!! 不存在'}")
# install.sh 期望 prebuilt_packages/HDSentinel-armv8 可执行文件
expected = os.path.join(pre, "HDSentinel-armv8")
print(f"  install.sh 期望的二进制 {os.path.basename(expected)} : "
      f"{'存在' if os.path.exists(expected) else '!! 不存在 (仅有 zip 压缩包，未解压就位)'}")

# 5) 其他
print("\n[5] 其他文件")
for f in sorted(os.listdir(pre)):
    if os.path.isfile(os.path.join(pre, f)):
        print(f"  {f}  ({os.path.getsize(os.path.join(pre, f))/1024:.1f} KB)")
