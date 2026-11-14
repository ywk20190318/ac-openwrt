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

[[ -f "$CONFIG_FILE" ]] || { echo "错误：找不到设备配置文件：$CONFIG_FILE" >&2; exit 1; }
[[ -f "$INI_FILE" ]] || { echo "错误：找不到设备信息文件：$INI_FILE" >&2; exit 1; }
[[ -d "$BUILD_DIR" ]] || { echo "错误：源码目录不存在：$BUILD_DIR（请先执行 pre_clone_action.sh）" >&2; exit 1; }

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


modify_kernel_size() {
    local image_mk="$BUILD_DIR/target/linux/qualcommax/image/ipq60xx.mk"
    if [[ -f "$image_mk" ]]; then
        sed -i '/link_nn6000-common/,/endef/{s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g;}' "$image_mk"
        echo "已检查 NN6000 内核分区大小配置。"
    else
        echo "警告：未找到 $image_mk，未修改内核分区大小。" >&2
    fi
}

apply_config
modify_kernel_size

cd "$BUILD_DIR"

# Hard-disable QuickStart before Kconfig resolution. This also guards against
# a package being selected indirectly by an upstream default or feed.
sed -i '/^CONFIG_PACKAGE_quickstart=/d; /^CONFIG_PACKAGE_luci-app-quickstart=/d' .config
cat >> .config <<'EOF'
CONFIG_PACKAGE_quickstart=n
CONFIG_PACKAGE_luci-app-quickstart=n
EOF

make defconfig

# Fail the build if QuickStart or iStoreOS app-store packages survive defconfig.
if grep -Eq '^CONFIG_PACKAGE_(quickstart|luci-app-quickstart|istore|istorex|luci-app-istore|luci-app-istorex|luci-app-store)=y$' .config; then
    echo "错误：QuickStart 或 iStoreOS 商店组件被重新选入 .config，已停止构建。" >&2
    grep -E '^CONFIG_PACKAGE_(quickstart|luci-app-quickstart|istore|istorex|luci-app-istore|luci-app-istorex|luci-app-store)=' .config >&2 || true
    exit 1
fi
echo "检查通过：QuickStart 和 iStoreOS 商店相关组件均已禁用。"

# Verify every package explicitly requested by the device config survived Kconfig.
# make defconfig can silently drop unknown package symbols; do not let that turn
# into a multi-hour build with missing drivers, utilities, or LuCI components.
REQUESTED_PACKAGES=()
while IFS= read -r package; do
    [[ -n "$package" ]] && REQUESTED_PACKAGES+=("$package")
done < <(sed -n 's/^CONFIG_PACKAGE_\([^=]*\)=y$/\1/p' "$CONFIG_FILE" | sort -u)

MISSING_PACKAGES=()
for package in "${REQUESTED_PACKAGES[@]}"; do
    if ! grep -qx "CONFIG_PACKAGE_${package}=y" .config; then
        MISSING_PACKAGES+=("$package")
    fi
done
if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
    echo "错误：以下设备配置中明确选择的软件包未通过 make defconfig，停止构建：" >&2
    printf '  - %s\n' "${MISSING_PACKAGES[@]}" >&2
    exit 1
fi
echo "检查通过：设备配置中 ${#REQUESTED_PACKAGES[@]} 个显式软件包选择全部保留。"

# Verify the exact NN6000 V2 device profile is still selected.
grep -qx 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_link_nn6000-v2=y' .config || {
    echo "错误：make defconfig 后 NN6000 V2 设备 profile 丢失，停止构建。" >&2
    exit 1
}
echo "检查通过：目标设备为 Link NN6000 V2（qualcommax/ipq60xx）。"


# Fail early if APK or the Simplified Chinese LuCI translation was dropped
# by Kconfig/feeds resolution; do not silently publish an OPKG or English-only image.
grep -qx 'CONFIG_USE_APK=y' .config || {
    echo "错误：make defconfig 后未启用 APK 包管理器。" >&2
    exit 1
}
if grep -qx 'CONFIG_USE_OPKG=y' .config; then
    echo "错误：检测到 OPKG 已启用；本固件必须仅使用 APK。" >&2
    exit 1
fi
grep -qx 'CONFIG_LUCI_LANG_zh_Hans=y' .config || {
    echo "错误：make defconfig 后未启用 LuCI 简体中文语言选项。" >&2
    exit 1
}
echo "检查通过：已启用 APK 包管理器和 LuCI 简体中文语言。"

# Validate every explicitly selected kernel module after Kconfig dependency resolution.
# This covers the complete retained upstream kmod selection, not just a short hard-coded list.
REQUIRED_KMODS=()
while IFS= read -r package; do
    [[ -n "$package" ]] && REQUIRED_KMODS+=("$package")
done < <(sed -n 's/^CONFIG_PACKAGE_\(kmod-[^=]*\)=y$/\1/p' .config | sort -u)

if [[ ${#REQUIRED_KMODS[@]} -eq 0 ]]; then
    echo "错误：配置中没有选中任何内核模块，拒绝继续构建。" >&2
    exit 1
fi
echo "已检测到 ${#REQUIRED_KMODS[@]} 个显式选择的内核模块，开始验证..."


if [[ "$BUILD_MOD" == "debug" ]]; then
    echo "调试模式：配置准备完成，按要求跳过实际编译。"
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
    echo "并行编译失败，正在改用单线程详细模式重试..." >&2
    make -j1 V=s
fi

[[ -d "$TARGET_DIR" ]] || { echo "错误：找不到目标固件输出目录：$TARGET_DIR" >&2; exit 1; }

find "$TARGET_DIR" -type f \( \
    -name '*.bin' -o -name '*.manifest' -o -name '*efi.img.gz' \
    -o -name '*.itb' -o -name '*.fip' -o -name '*.ubi' \
    -o -name '*rootfs.tar.gz' \
\) -exec cp -f {} "$FIRMWARE_DIR/" \;

rm -f "$FIRMWARE_DIR/Packages.manifest"

# Verify every explicitly selected kmod in the final image manifest.
MANIFEST_FILE="$(find "$FIRMWARE_DIR" -maxdepth 1 -type f -name '*.manifest' -print -quit)"
if [[ -z "$MANIFEST_FILE" ]]; then
    echo "错误：未生成固件软件包清单，无法验证内核模块。" >&2
    exit 1
fi
MISSING_KMODS=()
for package in "${REQUIRED_KMODS[@]}"; do
    if ! awk -v package="$package" '$1 == package { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
        MISSING_KMODS+=("$package")
    fi
done
if [[ ${#MISSING_KMODS[@]} -gt 0 ]]; then
    printf '错误：最终固件缺少以下已选择内核模块：\n' >&2
    printf '  - %s\n' "${MISSING_KMODS[@]}" >&2
    exit 1
fi
echo "检查通过：最终固件清单包含全部 ${#REQUIRED_KMODS[@]} 个显式选择的内核模块。"

# Verify every package explicitly selected in the device config is present in
# the final image manifest, not merely left enabled in .config.
MISSING_IMAGE_PACKAGES=()
for package in "${REQUESTED_PACKAGES[@]}"; do
    if ! awk -v package="$package" '$1 == package { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
        MISSING_IMAGE_PACKAGES+=("$package")
    fi
done
if [[ ${#MISSING_IMAGE_PACKAGES[@]} -gt 0 ]]; then
    echo "错误：以下显式选择的软件包未进入最终固件 manifest：" >&2
    printf '  - %s\n' "${MISSING_IMAGE_PACKAGES[@]}" >&2
    exit 1
fi
echo "检查通过：设备配置中 ${#REQUESTED_PACKAGES[@]} 个显式软件包全部进入最终固件 manifest。"

# Reject QuickStart and iStoreOS store packages even if selected indirectly by a feed.
if grep -Eiq '(^|[[:space:]])(quickstart|luci-app-quickstart|istore|istorex|luci-app-istore|luci-app-istorex|luci-app-store)([[:space:]]|$)' "$MANIFEST_FILE"; then
    echo "错误：最终固件 manifest 仍包含 QuickStart 或 iStoreOS 商店相关软件包。" >&2
    grep -Ein '(quick.?start|istore|luci-app-store)' "$MANIFEST_FILE" >&2 || true
    exit 1
fi
echo "检查通过：最终固件 manifest 不包含 QuickStart 和 iStoreOS 商店相关软件包。"


if ! find "$FIRMWARE_DIR" -maxdepth 1 -type f | grep -q .; then
    echo "错误：编译流程结束，但未收集到任何固件产物。" >&2
    exit 1
fi

echo "===== 固件产物清单 ====="
find "$FIRMWARE_DIR" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
echo "===== 编译缓存已保留：$BUILD_DIR/.ccache ====="
