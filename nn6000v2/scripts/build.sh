#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$BASE_PATH/.." && pwd)"

DEV="${1:?Usage: $0 <device_model> [debug]}"
BUILD_MOD="${2:-}"
CONFIG_FILE="$BASE_PATH/configs/kernel/${DEV}.config"
INI_FILE="$BASE_PATH/configs/${DEV}.ini"
BUILD_DIR="$REPO_ROOT/action_build"

[[ -f "$CONFIG_FILE" ]] || { echo "Missing config: $CONFIG_FILE" >&2; exit 1; }
[[ -f "$INI_FILE" ]] || { echo "Missing device ini: $INI_FILE" >&2; exit 1; }
[[ -d "$BUILD_DIR" ]] || { echo "Missing source tree: $BUILD_DIR (run pre_clone_action.sh first)" >&2; exit 1; }

read_ini() {
    local key="$1"
    awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$INI_FILE"
}

REPO_URL="$(read_ini REPO_URL)"
REPO_BRANCH="$(read_ini REPO_BRANCH)"
REPO_BRANCH="${REPO_BRANCH:-main}"
COMMIT_HASH="$(read_ini COMMIT_HASH)"
COMMIT_HASH="${COMMIT_HASH:-none}"

# Keep the existing modular update pipeline and its package/system customizations.
"$SCRIPT_DIR/update.sh" "$REPO_URL" "$REPO_BRANCH" "$BUILD_DIR" "$COMMIT_HASH"

apply_config() {
    cp -f "$CONFIG_FILE" "$BUILD_DIR/.config"
    if grep -qE 'CONFIG_TARGET_qualcommax_ipq60xx=y|CONFIG_TARGET_qualcommax_ipq807x=y' "$BUILD_DIR/.config" &&
       ! grep -q '^CONFIG_GIT_MIRROR' "$BUILD_DIR/.config"; then
        cat "$BASE_PATH/configs/kernel/nss.config" >> "$BUILD_DIR/.config"
    fi
}

remove_uhttpd_dependency() {
    local config_path="$BUILD_DIR/.config"
    local luci_makefile="$BUILD_DIR/feeds/luci/collections/luci/Makefile"
    if grep -q '^CONFIG_PACKAGE_luci-app-quickfile=y' "$config_path" && [[ -f "$luci_makefile" ]]; then
        sed -i '/luci-light/d' "$luci_makefile"
        echo "Removed luci-light dependency for QuickFile/Nginx profile."
    fi
}

modify_kernel_size() {
    local image_mk="$BUILD_DIR/target/linux/qualcommax/image/ipq60xx.mk"
    if [[ -f "$image_mk" ]]; then
        sed -i '/link_nn6000-common/,/endef/{s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g;}' "$image_mk"
        echo "Checked NN6000 kernel partition size."
    else
        echo "WARNING: $image_mk not found; kernel size was not modified." >&2
    fi
}

apply_config
remove_uhttpd_dependency
modify_kernel_size

cd "$BUILD_DIR"
make defconfig

# Fail early if feed/config resolution drops the LuCI collection or reintroduces
# container runtimes. This catches the previous default-settings -> luci issue
# before spending hours compiling the firmware.
if ! grep -q '^CONFIG_PACKAGE_luci=y
if [[ "$BUILD_MOD" == "debug" ]]; then
    echo "Debug mode: configuration prepared; build skipped."
    exit 0
fi

TARGET_DIR="$BUILD_DIR/bin/targets"
FIRMWARE_DIR="$REPO_ROOT/firmware"
rm -rf "$FIRMWARE_DIR"
mkdir -p "$FIRMWARE_DIR"

# Remove only old target artifacts; keep build/staging and compiler cache intact.
if [[ -d "$TARGET_DIR" ]]; then
    find "$TARGET_DIR" -type f \( \
        -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
        -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
        -o -name '*rootfs.tar.gz' \
    \) -delete
fi

make download -j"$(($(nproc) * 2))"
if ! make -j"$(($(nproc) + 1))"; then
    echo "Parallel build failed; retrying serial verbose build..." >&2
    make -j1 V=s
fi

[[ -d "$TARGET_DIR" ]] || { echo "Target output directory missing: $TARGET_DIR" >&2; exit 1; }

find "$TARGET_DIR" -type f \( \
    -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
    -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
    -o -name '*rootfs.tar.gz' \
\) -exec cp -f {} "$FIRMWARE_DIR/" \;

rm -f "$FIRMWARE_DIR/Packages.manifest"
if ! find "$FIRMWARE_DIR" -maxdepth 1 -type f | grep -q .; then
    echo "ERROR: build completed but no firmware artifacts were collected." >&2
    exit 1
fi

echo "===== Firmware artifacts ====="
find "$FIRMWARE_DIR" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
echo "===== Compiler cache preserved at $BUILD_DIR/.ccache ====="
 .config; then
    echo "ERROR: LuCI collection is not selected after make defconfig." >&2
    echo "Check feeds installation and the default-settings dependency." >&2
    exit 1
fi

if grep -Eq '^CONFIG_PACKAGE_(docker|dockerd|containerd|runc|docker-compose|luci-app-dockerman|podman)=y
if [[ "$BUILD_MOD" == "debug" ]]; then
    echo "Debug mode: configuration prepared; build skipped."
    exit 0
fi

TARGET_DIR="$BUILD_DIR/bin/targets"
FIRMWARE_DIR="$REPO_ROOT/firmware"
rm -rf "$FIRMWARE_DIR"
mkdir -p "$FIRMWARE_DIR"

# Remove only old target artifacts; keep build/staging and compiler cache intact.
if [[ -d "$TARGET_DIR" ]]; then
    find "$TARGET_DIR" -type f \( \
        -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
        -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
        -o -name '*rootfs.tar.gz' \
    \) -delete
fi

make download -j"$(($(nproc) * 2))"
if ! make -j"$(($(nproc) + 1))"; then
    echo "Parallel build failed; retrying serial verbose build..." >&2
    make -j1 V=s
fi

[[ -d "$TARGET_DIR" ]] || { echo "Target output directory missing: $TARGET_DIR" >&2; exit 1; }

find "$TARGET_DIR" -type f \( \
    -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
    -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
    -o -name '*rootfs.tar.gz' \
\) -exec cp -f {} "$FIRMWARE_DIR/" \;

rm -f "$FIRMWARE_DIR/Packages.manifest"
if ! find "$FIRMWARE_DIR" -maxdepth 1 -type f | grep -q .; then
    echo "ERROR: build completed but no firmware artifacts were collected." >&2
    exit 1
fi

echo "===== Firmware artifacts ====="
find "$FIRMWARE_DIR" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
echo "===== Compiler cache preserved at $BUILD_DIR/.ccache ====="
 .config; then
    echo "ERROR: a container runtime was unexpectedly selected in this minimal profile." >&2
    grep -E '^CONFIG_PACKAGE_(docker|dockerd|containerd|runc|docker-compose|luci-app-dockerman|podman)=y
if [[ "$BUILD_MOD" == "debug" ]]; then
    echo "Debug mode: configuration prepared; build skipped."
    exit 0
fi

TARGET_DIR="$BUILD_DIR/bin/targets"
FIRMWARE_DIR="$REPO_ROOT/firmware"
rm -rf "$FIRMWARE_DIR"
mkdir -p "$FIRMWARE_DIR"

# Remove only old target artifacts; keep build/staging and compiler cache intact.
if [[ -d "$TARGET_DIR" ]]; then
    find "$TARGET_DIR" -type f \( \
        -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
        -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
        -o -name '*rootfs.tar.gz' \
    \) -delete
fi

make download -j"$(($(nproc) * 2))"
if ! make -j"$(($(nproc) + 1))"; then
    echo "Parallel build failed; retrying serial verbose build..." >&2
    make -j1 V=s
fi

[[ -d "$TARGET_DIR" ]] || { echo "Target output directory missing: $TARGET_DIR" >&2; exit 1; }

find "$TARGET_DIR" -type f \( \
    -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
    -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
    -o -name '*rootfs.tar.gz' \
\) -exec cp -f {} "$FIRMWARE_DIR/" \;

rm -f "$FIRMWARE_DIR/Packages.manifest"
if ! find "$FIRMWARE_DIR" -maxdepth 1 -type f | grep -q .; then
    echo "ERROR: build completed but no firmware artifacts were collected." >&2
    exit 1
fi

echo "===== Firmware artifacts ====="
find "$FIRMWARE_DIR" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
echo "===== Compiler cache preserved at $BUILD_DIR/.ccache ====="
 .config >&2
    exit 1
fi

if grep -q '^CONFIG_PACKAGE_kmod-nft-compat=y
if [[ "$BUILD_MOD" == "debug" ]]; then
    echo "Debug mode: configuration prepared; build skipped."
    exit 0
fi

TARGET_DIR="$BUILD_DIR/bin/targets"
FIRMWARE_DIR="$REPO_ROOT/firmware"
rm -rf "$FIRMWARE_DIR"
mkdir -p "$FIRMWARE_DIR"

# Remove only old target artifacts; keep build/staging and compiler cache intact.
if [[ -d "$TARGET_DIR" ]]; then
    find "$TARGET_DIR" -type f \( \
        -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
        -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
        -o -name '*rootfs.tar.gz' \
    \) -delete
fi

make download -j"$(($(nproc) * 2))"
if ! make -j"$(($(nproc) + 1))"; then
    echo "Parallel build failed; retrying serial verbose build..." >&2
    make -j1 V=s
fi

[[ -d "$TARGET_DIR" ]] || { echo "Target output directory missing: $TARGET_DIR" >&2; exit 1; }

find "$TARGET_DIR" -type f \( \
    -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
    -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
    -o -name '*rootfs.tar.gz' \
\) -exec cp -f {} "$FIRMWARE_DIR/" \;

rm -f "$FIRMWARE_DIR/Packages.manifest"
if ! find "$FIRMWARE_DIR" -maxdepth 1 -type f | grep -q .; then
    echo "ERROR: build completed but no firmware artifacts were collected." >&2
    exit 1
fi

echo "===== Firmware artifacts ====="
find "$FIRMWARE_DIR" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
echo "===== Compiler cache preserved at $BUILD_DIR/.ccache ====="
 .config; then
    echo "ERROR: kmod-nft-compat is selected; this reintroduces the legacy xtables module clash." >&2
    exit 1
fi

echo "===== Minimal profile checks passed ====="
grep -E '^CONFIG_PACKAGE_(luci|default-settings|default-settings-chn|autocore)=y
if [[ "$BUILD_MOD" == "debug" ]]; then
    echo "Debug mode: configuration prepared; build skipped."
    exit 0
fi

TARGET_DIR="$BUILD_DIR/bin/targets"
FIRMWARE_DIR="$REPO_ROOT/firmware"
rm -rf "$FIRMWARE_DIR"
mkdir -p "$FIRMWARE_DIR"

# Remove only old target artifacts; keep build/staging and compiler cache intact.
if [[ -d "$TARGET_DIR" ]]; then
    find "$TARGET_DIR" -type f \( \
        -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
        -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
        -o -name '*rootfs.tar.gz' \
    \) -delete
fi

make download -j"$(($(nproc) * 2))"
if ! make -j"$(($(nproc) + 1))"; then
    echo "Parallel build failed; retrying serial verbose build..." >&2
    make -j1 V=s
fi

[[ -d "$TARGET_DIR" ]] || { echo "Target output directory missing: $TARGET_DIR" >&2; exit 1; }

find "$TARGET_DIR" -type f \( \
    -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
    -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
    -o -name '*rootfs.tar.gz' \
\) -exec cp -f {} "$FIRMWARE_DIR/" \;

rm -f "$FIRMWARE_DIR/Packages.manifest"
if ! find "$FIRMWARE_DIR" -maxdepth 1 -type f | grep -q .; then
    echo "ERROR: build completed but no firmware artifacts were collected." >&2
    exit 1
fi

echo "===== Firmware artifacts ====="
find "$FIRMWARE_DIR" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
echo "===== Compiler cache preserved at $BUILD_DIR/.ccache ====="
 .config || true


if [[ "$BUILD_MOD" == "debug" ]]; then
    echo "Debug mode: configuration prepared; build skipped."
    exit 0
fi

TARGET_DIR="$BUILD_DIR/bin/targets"
FIRMWARE_DIR="$REPO_ROOT/firmware"
rm -rf "$FIRMWARE_DIR"
mkdir -p "$FIRMWARE_DIR"

# Remove only old target artifacts; keep build/staging and compiler cache intact.
if [[ -d "$TARGET_DIR" ]]; then
    find "$TARGET_DIR" -type f \( \
        -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
        -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
        -o -name '*rootfs.tar.gz' \
    \) -delete
fi

make download -j"$(($(nproc) * 2))"
if ! make -j"$(($(nproc) + 1))"; then
    echo "Parallel build failed; retrying serial verbose build..." >&2
    make -j1 V=s
fi

[[ -d "$TARGET_DIR" ]] || { echo "Target output directory missing: $TARGET_DIR" >&2; exit 1; }

find "$TARGET_DIR" -type f \( \
    -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
    -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
    -o -name '*rootfs.tar.gz' \
\) -exec cp -f {} "$FIRMWARE_DIR/" \;

rm -f "$FIRMWARE_DIR/Packages.manifest"
if ! find "$FIRMWARE_DIR" -maxdepth 1 -type f | grep -q .; then
    echo "ERROR: build completed but no firmware artifacts were collected." >&2
    exit 1
fi

echo "===== Firmware artifacts ====="
find "$FIRMWARE_DIR" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
echo "===== Compiler cache preserved at $BUILD_DIR/.ccache ====="
