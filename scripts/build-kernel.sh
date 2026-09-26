#!/usr/bin/env bash
set -euo pipefail
ROOT="$PWD"
DIST="$ROOT/dist"
mkdir -p "$DIST" "$ROOT/build"
exec > >(tee "$DIST/build.log") 2>&1
KERNEL_COMMIT=151cf2b6bfbe73fc93392a22d7165cc9d96c10b4
export ARCH=arm64 LLVM=1 LLVM_IAS=1
export KBUILD_BUILD_USER=builder KBUILD_BUILD_HOST=tb375fc-droidspaces
export KBUILD_BUILD_TIMESTAMP='Sat Jun 28 07:50:58 UTC 2025'
export KBUILD_BUILD_VERSION=1
export KCFLAGS=-D__ANDROID_COMMON_KERNEL__
export LOCALVERSION=-android14-11-g151cf2b6bfbe-ab13719792
unset BUILD_NUMBER

git init build/common
git -C build/common remote add origin https://github.com/aosp-mirror/kernel_common.git
git -C build/common fetch --depth=1 origin "$KERNEL_COMMIT"
git -C build/common checkout --detach FETCH_HEAD
test "$(git -C build/common rev-parse HEAD)" = "$KERNEL_COMMIT"

# Android's fixed release tag contains the same r487747c toolchain generation.
git init build/clang
git -C build/clang remote add origin https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
git -C build/clang config core.sparseCheckout true
printf '/clang-r487747c/\n' > build/clang/.git/info/sparse-checkout
git -C build/clang fetch --depth=1 --filter=blob:none origin refs/tags/android-14.0.0_r1
git -C build/clang checkout --detach FETCH_HEAD
git -C build/clang rev-parse HEAD > "$DIST/toolchain-commit.txt"
export PATH="$ROOT/build/clang/clang-r487747c/bin:$PATH"
clang --version | tee "$DIST/clang-version.txt"
grep -q 'clang version 17.0.2' "$DIST/clang-version.txt"
test "$(command -v clang)" = "$ROOT/build/clang/clang-r487747c/bin/clang"

SRC="$ROOT/build/common"
OUT="$ROOT/build/out"
mkdir -p "$OUT"
# Retain trust in stock signed system_dlkm modules. This is a public
# certificate extracted from the stock boot kernel, not a signing key.
openssl x509 -in "$ROOT/config/stock-module-cert.pem" -outform DER -out "$DIST/stock-module-cert.der"
printf '%s  %s\n' '1c147ca07da8dc7bc6f089ad208a9d3d4ffe3795ea24f3125aa29b1b37179c01' "$DIST/stock-module-cert.der" | sha256sum -c -
cp "$ROOT/config/stock-module-cert.pem" "$SRC/certs/stock-module-cert.pem"
cp config/stock.config "$OUT/.config"
# Export retention is a build-system input in Kleaf; keep all exports for this
# first diagnostic build, then compare their CRCs before considering flashing.
"$SRC/scripts/config" --file "$OUT/.config" -d TRIM_UNUSED_KSYMS -d LOCALVERSION_AUTO
"$SRC/scripts/config" --file "$OUT/.config" --set-str SYSTEM_TRUSTED_KEYS 'certs/stock-module-cert.pem'
make -C "$SRC" O="$OUT" olddefconfig
cp "$OUT/.config" "$DIST/baseline.config"
make -C "$SRC" O="$OUT" -j2 Image modules
cp "$OUT/Module.symvers" "$DIST/baseline.Module.symvers"
pahole -C task_struct "$OUT/vmlinux" > "$DIST/baseline.task_struct.txt"
cp "$OUT/include/config/kernel.release" "$DIST/kernel.release"
test "$(cat "$DIST/kernel.release")" = '6.1.138-android14-11-g151cf2b6bfbe-ab13719792'

git -C "$SRC" apply --check "$ROOT/patches/droidspaces-sysvipc.patch"
git -C "$SRC" apply "$ROOT/patches/droidspaces-sysvipc.patch"
for feature in SYSVIPC POSIX_MQUEUE PID_NS IPC_NS USER_NS DEVTMPFS; do
  "$SRC/scripts/config" --file "$OUT/.config" -e "$feature"
done
make -C "$SRC" O="$OUT" olddefconfig
for feature in SYSVIPC POSIX_MQUEUE PID_NS IPC_NS USER_NS DEVTMPFS; do
  grep -qx "CONFIG_${feature}=y" "$OUT/.config"
done
cp "$OUT/.config" "$DIST/droidspaces.config"
make -C "$SRC" O="$OUT" -j2 Image modules
cp "$OUT/Module.symvers" "$DIST/droidspaces.Module.symvers"
pahole -C task_struct "$OUT/vmlinux" > "$DIST/droidspaces.task_struct.txt"
python3 scripts/check-abi.py "$DIST"
cp "$OUT/arch/arm64/boot/Image" "$DIST/Image-UNTESTED"
python3 - "$DIST" <<'PY'
import pathlib, sys
d = pathlib.Path(sys.argv[1])
assert (d / 'stock-module-cert.der').read_bytes() in (d / 'Image-UNTESTED').read_bytes(), 'Stock module certificate missing from built kernel'
(d / 'stock-module-trust-check.txt').write_text('PASS: exact stock public certificate is embedded in candidate kernel.\n')
PY
lz4 -l -12 "$DIST/Image-UNTESTED" "$DIST/Image-UNTESTED.lz4"
git -C "$SRC" diff > "$DIST/applied.patch"
printf '%s\n' "$KERNEL_COMMIT" > "$DIST/kernel-commit.txt"
printf '%s\n' 'NOT FLASH READY: requires stock vendor CRC, task layout, module signing and hardware boot checks.' > "$DIST/NOT-FLASH-READY.txt"
(cd "$DIST" && sha256sum Image-UNTESTED* > SHA256SUMS)
