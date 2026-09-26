# TB375FC Droidspaces kernel candidate

Diagnostic build for Lenovo TB375FC, Android 16 / ZUXOS 1.5.10.044.

## Pinned inputs
- Android common kernel: `151cf2b6bfbe73fc93392a22d7165cc9d96c10b4` (6.1.138, android14-6.1, KMI generation 11).
- Toolchain: Android prebuilt `clang-r487747c` from tag `android-14.0.0_r1`; version checked as 17.0.2, actual repository commit recorded in artifacts.
- Stock configuration extracted directly from the device's boot image.
- SYSVIPC patch: Droidspaces-OSS commit `cff50fa04d50472b607ba6822e8bf482b19cd427`, `001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`.

## What it does
Build the original configuration first, then enable SYSVIPC, POSIX_MQUEUE,
PID_NS, IPC_NS, USER_NS and DEVTMPFS with the SYSVIPC kABI patch.
Compare exported symbol CRCs and task_struct size. Preserve both structure
layout reports for manual inspection. Existing KernelSU LKM is kept separate.
TRIM_UNUSED_KSYMS is disabled for this diagnostic build because the stock
Kleaf-generated whitelist is not included. LOCALVERSION_AUTO is disabled and
the original release suffix is supplied explicitly for module compatibility.
The custom build hostname identifies this as a non-stock build.

## Run
Commit all files, including `.github/workflows/build-kernel.yml`, to the repository.
The push starts the workflow; it can also be started from Actions manually.
The workflow has read-only repository permissions and uploads artifacts only.
No releases, device serials, partition images or credentials are published.

## Status and limits
Local shell/Python syntax and patch application checks passed.
Cloud compilation has NOT yet succeeded or been tested.
The candidate is NOT FLASH READY. Before flashing: check stock vendor module
CRCs, all existing task_struct member offsets, signed GKI module trust,
KernelSU LKM compatibility, image compression, AVB metadata and recovery.
Passing the included checks does not prove hardware compatibility.
Do not replace system/vendor modules with this build's modules automatically.

Sources:
- https://github.com/aosp-mirror/kernel_common/commit/151cf2b6bfbe73fc93392a22d7165cc9d96c10b4
- https://github.com/ravindu644/Droidspaces-OSS/blob/cff50fa04d50472b607ba6822e8bf482b19cd427/Documentation/Kernel-Configuration.md
