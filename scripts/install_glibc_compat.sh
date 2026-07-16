#!/bin/sh
GLIBC_DIR="/lib/glibc-aarch64"
MIRROR="https://mirrors.tuna.tsinghua.edu.cn/debian"
RELEASE="trixie"
ARCH="arm64"
TMP="/tmp/glibc_setup"

echo "=== 1. 创建目录 ==="
rm -rf "$TMP" "$GLIBC_DIR"
mkdir -p "$TMP" "$GLIBC_DIR"

echo "=== 2. 下载 Packages.gz ==="
PKGINFO=""
for m in "$MIRROR" "https://deb.debian.org/debian"; do
    PKGINFO=$(curl -sL --connect-timeout 10 --max-time 60 "${m}/dists/${RELEASE}/main/binary-${ARCH}/Packages.gz" | gunzip -c 2>/dev/null)
    [ -n "$PKGINFO" ] && break
done
[ -z "$PKGINFO" ] && { echo "ERROR: Packages.gz"; exit 1; }
echo "  OK"

echo "=== 3. 下载并解压 Debian 包 ==="
for pkg in "libc6" "libgcc-s1" "libstdc++6"; do
    echo "--- $pkg ---"
    VER=$(echo "$PKGINFO" | awk -v pkg="$pkg" '/^Package: /{p=$2} p==pkg&&/^Version:/{print $2;exit}')
    [ -z "$VER" ] && { echo "  SKIP: no version"; continue; }
    echo "  版本: $VER"

    FN=$(echo "$PKGINFO" | awk -v pkg="$pkg" -v ver="$VER" '/^Package:/{p=$2} p==pkg&&/^Version:/{v=$2} p==pkg&&v==ver&&/^Filename:/{print $2;exit}')
    [ -z "$FN" ] && FN="pool/main/${pkg:0:1}/${pkg}/${pkg}_${VER}_${ARCH}.deb"
    echo "  路径: $FN"

    DL_OK=0
    for m in "$MIRROR" "https://deb.debian.org/debian" "https://ftp.debian.org/debian"; do
        echo "  尝试 $m ..."
        curl -sL --connect-timeout 10 --max-time 180 -o "$TMP/${pkg}.deb" "${m}/${FN}" 2>/dev/null
        FS=$(wc -c < "$TMP/${pkg}.deb" 2>/dev/null || echo 0)
        [ "$FS" -gt 1000 ] && { DL_OK=1; break; }
    done
    [ "$DL_OK" -eq 0 ] && { echo "  SKIP: download failed"; continue; }
    echo "  已下载 ($(ls -lh "$TMP/${pkg}.deb" | awk '{print $5}'))"

    mkdir -p "$TMP/${pkg}_extract"
    bsdtar -xf "$TMP/${pkg}.deb" -C "$TMP/${pkg}_extract" 2>/dev/null || { echo "  SKIP: bsdtar"; continue; }
    for dt in "$TMP/${pkg}_extract/data.tar."*; do
        [ -f "$dt" ] && bsdtar -xf "$dt" -C "$TMP/${pkg}_extract" 2>/dev/null || true
    done

    find "$TMP/${pkg}_extract" -name "*.so*" -type f | while read f; do
        b=$(basename "$f")
        case "$b" in
            libc.so.*|libm.so.*|libpthread.so.*|librt.so.*|libdl.so.*|libutil.so.*) ;;
            libresolv.so.*|libnss_*.so.*|libnsl.so.*|libanl.so.*|libBrokenLocale.so.*) ;;
            libthread_db.so.*|libgcc_s.so.*|libstdc++.so.*|libc_malloc_debug.so.*) ;;
            libmemusage.so|libpcprofile.so|libmvec.so.*|ld-linux-aarch64*) ;;
            *) continue ;;
        esac
        cp -f "$f" "$GLIBC_DIR/$b" 2>/dev/null && echo "    提取: $b"
    done
    find "$TMP/${pkg}_extract" -name "*.so*" -type l | while read l; do
        tgt=$(readlink "$l" 2>/dev/null || true); bn=$(basename "$l")
        [ -n "$tgt" ] && [ -f "$GLIBC_DIR/$tgt" ] && ln -sf "$tgt" "$GLIBC_DIR/$bn" 2>/dev/null || true
    done
    rm -rf "$TMP/${pkg}_extract" "$TMP/${pkg}.deb"
done

echo "=== 4. 创建 glibc-run ==="
cat <<'GLIBC_RUN' > /usr/bin/glibc-run
#!/bin/sh
GLIBC_DIR="/lib/glibc-aarch64"
LOADER="$GLIBC_DIR/ld-linux-aarch64.so.1"
[ -f "$LOADER" ] || { echo "glibc compat not installed" >&2; exit 1; }
[ $# -ge 1 ] || { echo "Usage: $0 <binary> [args...]" >&2; exit 1; }
BINARY="$1"; shift
[ -f "$BINARY" ] || { echo "File not found: $BINARY" >&2; exit 1; }
export LD_LIBRARY_PATH="$GLIBC_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$LOADER" "$BINARY" "$@"
GLIBC_RUN
chmod +x /usr/bin/glibc-run

echo "=== 5. 创建 init 脚本 ==="
cat <<'GLIBC_INIT' > /etc/init.d/glibc-compat
#!/bin/sh /etc/rc.common
START=10
boot() {
    local LD="/lib/glibc-aarch64/ld-linux-aarch64.so.1"
    [ -f "$LD" ] && logger -t glibc-compat "glibc compat ready" || logger -t glibc-compat "WARNING: glibc compat missing"
}
start() { boot; }
stop() { return 0; }
GLIBC_INIT
chmod +x /etc/init.d/glibc-compat
/etc/init.d/glibc-compat enable 2>/dev/null || true

echo ""
echo "=== 安装结果 ==="
ls -la "$GLIBC_DIR/"
echo ""
echo "=== 完成 ==="
