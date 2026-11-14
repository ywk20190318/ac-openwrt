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
make defconfig

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

# Nginx is the only web server in this image; fail if legacy uHTTPd returns.
if grep -Eq '^CONFIG_PACKAGE_uhttpd(-mod-[^=]+)?=y' .config; then
    echo "错误：检测到 uHTTPd 或其模块被选中；本固件只使用 Nginx。" >&2
    exit 1
fi
echo "检查通过：uHTTPd 及其模块未被选入固件。"

# Validate the explicitly requested networking and external-storage modules.
REQUIRED_KMODS=(
    kmod-nft-tproxy
    kmod-tun
    kmod-nft-fullcone
    kmod-nft-bridge
    kmod-tcp-bbr
    kmod-netlink-diag
    kmod-inet-diag
    kmod-tls
    kmod-bonding
    kmod-vxlan
    kmod-geneve
    kmod-ipip
    kmod-ipsec
    kmod-ipsec4
    kmod-ipsec6
    kmod-sit
    kmod-ip6-tunnel
    kmod-gre
    kmod-gre6
    kmod-veth
    kmod-vrf
    kmod-macvlan
    kmod-ipvlan
    kmod-ifb
    kmod-wireguard
    kmod-ppp
    kmod-pppoe
    kmod-pppox
    kmod-pptp
    kmod-pppol2tp
    kmod-l2tp
    kmod-sctp
    kmod-mpls
    kmod-sched-core
    kmod-sched-cake
    kmod-sched-fq-pie
    kmod-sched-flower
    kmod-sched-connmark
    kmod-netem
    kmod-tcp-hybla
    kmod-tcp-scalable
    kmod-sctp-diag
    kmod-unix-diag
    kmod-packet-diag
    kmod-nf-conntrack
    kmod-nf-nat
    kmod-nf-flow
    kmod-nf-socket
    kmod-nf-tproxy
    kmod-nf-reject
    kmod-nfnetlink
    kmod-nfnetlink-log
    kmod-nfnetlink-queue
    kmod-nf-conntrack-netlink
    kmod-nft-core
    kmod-nft-arp
    kmod-nft-dup-inet
    kmod-nft-queue
    kmod-nft-compat
    kmod-nft-xfrm
    kmod-br-netfilter
    kmod-ipt-core
    kmod-ipt-filter
    kmod-ipt-nat
    kmod-ipt-conntrack
    kmod-ipt-socket
    kmod-ipt-tproxy
    kmod-ipt-extra
    kmod-ip6tables
    kmod-ip6tables-extra
    kmod-fs-btrfs
    kmod-fs-cifs
    kmod-fs-ksmbd
    kmod-fs-nfs
    kmod-fs-nfs-common
    kmod-fs-nfs-v3
    kmod-fs-nfs-v4
    kmod-fs-nfsd
    kmod-fs-squashfs
    kmod-fs-isofs
    kmod-fs-udf
    kmod-fs-jfs
    kmod-fs-minix
    kmod-fs-reiserfs
    kmod-fs-hfs
    kmod-fs-hfsplus
    kmod-fs-autofs4
    kmod-fs-configfs
    kmod-fs-9p
    kmod-fuse
    kmod-ata-core
    kmod-scsi-core
    kmod-scsi-generic
    kmod-cdrom
    kmod-loop
    kmod-nbd
    kmod-dm
    kmod-dm-raid
    kmod-md-mod
    kmod-md-raid0
    kmod-md-raid1
    kmod-md-raid10
    kmod-md-raid456
    kmod-usb-net
    kmod-usb-net-aqc111
    kmod-usb-net-asix
    kmod-usb-net-asix-ax88179
    kmod-usb-net-cdc-ether
    kmod-usb-net-cdc-ncm
    kmod-usb-net-cdc-mbim
    kmod-usb-net-qmi-wwan
    kmod-usb-net-rtl8150
    kmod-usb-net-rtl8152
    kmod-usb-net-lan78xx
    kmod-usb-serial
    kmod-usb-serial-option
    kmod-usb-serial-qualcomm
    kmod-usb-storage
    kmod-usb-storage-uas
    kmod-usb-storage-extras
    kmod-usb2
    kmod-usb3
    kmod-usb-dwc3
    kmod-usb-xhci-hcd
    kmod-usb-ehci
    kmod-usb-ohci
    kmod-fs-ext4
    kmod-fs-vfat
    kmod-fs-msdos
    kmod-nls-base
    kmod-nls-utf8
    kmod-nls-cp932
    kmod-nls-cp936
    kmod-nls-cp950
    kmod-fs-exfat
    kmod-fs-ntfs3
    kmod-fs-f2fs
    kmod-fs-xfs
)
for package in "${REQUIRED_KMODS[@]}"; do
    grep -qx "CONFIG_PACKAGE_${package}=y" .config || {
        echo "错误：必需内核模块 ${package} 在 make defconfig 后未被选中。" >&2
        exit 1
    }
done
echo "检查通过：网络功能与 USB/文件系统内核模块均已选中。"

REQUIRED_PACKAGES=(
    luci-nginx
    luci-theme-argon
    luci-app-quickfile
    quickfile
    luci-app-openclash
    luci-app-diskman
    parted
    smartmontools
    blkid
    e2fsprogs
    btrfs-progs
    lsblk
    ntfs-3g-utils
    dosfstools
    exfat-mkfs
    exfat-fsck
    bash
    curl
    ca-bundle
    ip-full
    ruby
    ruby-yaml
    unzip
    luci-compat
    dnsmasq-full
    nginx-ssl
    nginx-util
    nginx-mod-luci
    nginx-mod-ubus
    uwsgi
    uwsgi-luci-support
    block-mount
    ntfs3-mount
    fuse-utils
    usbutils
    sgdisk
    resize2fs
)
for package in "${REQUIRED_PACKAGES[@]}"; do
    grep -qx "CONFIG_PACKAGE_${package}=y" .config || {
        echo "错误：必需软件包 ${package} 在 make defconfig 后未被选中。" >&2
        exit 1
    }
done
echo "检查通过：OpenClash、QuickFile、Diskman、Nginx 和存储工具均已在配置中选中。"

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

# Verify the final firmware manifest, not just the requested Kconfig selections.
MANIFEST_FILE="$(find "$FIRMWARE_DIR" -maxdepth 1 -type f -name '*.manifest' -print -quit)"
if [[ -z "$MANIFEST_FILE" ]]; then
    echo "错误：未生成固件软件包清单，无法验证本次选择的内核模块和 QuickFile 组件。" >&2
    exit 1
fi
for package in "${REQUIRED_KMODS[@]}"; do
    if ! awk -v package="$package" '$1 == package { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
        echo "错误：最终固件软件包清单缺少指定内核模块：$package" >&2
        exit 1
    fi
done
echo "检查通过：最终固件清单包含全部网络、USB 与文件系统内核模块。"

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! awk -v package="$package" '$1 == package { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
        echo "错误：最终固件软件包清单缺少必需组件：$package" >&2
        exit 1
    fi
done
echo "检查通过：OpenClash、QuickFile、Diskman、Nginx 和磁盘管理基础工具均已进入最终固件。"

# Verify that the final image does not contain the obsolete uHTTPd stack.
if awk '$1 ~ /^uhttpd($|-)/ { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
    echo "错误：最终固件清单仍包含 uHTTPd 相关软件包。" >&2
    exit 1
fi
echo "检查通过：最终固件不包含 uHTTPd 及其模块。"

if ! find "$FIRMWARE_DIR" -maxdepth 1 -type f | grep -q .; then
    echo "错误：编译流程结束，但未收集到任何固件产物。" >&2
    exit 1
fi

echo "===== 固件产物清单 ====="
find "$FIRMWARE_DIR" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
echo "===== 编译缓存已保留：$BUILD_DIR/.ccache ====="
 .config; then
    echo "错误：检测到 uHTTPd 或其模块被选中；本固件只使用 Nginx。" >&2
    exit 1
fi
echo "检查通过：uHTTPd 及其模块未被选入固件。"

# Validate the explicitly requested networking and external-storage modules.
REQUIRED_KMODS=(
    kmod-nft-tproxy
    kmod-tun
    kmod-nft-fullcone
    kmod-nft-bridge
    kmod-tcp-bbr
    kmod-netlink-diag
    kmod-inet-diag
    kmod-tls
    kmod-bonding
    kmod-vxlan
    kmod-geneve
    kmod-ipip
    kmod-ipsec
    kmod-ipsec4
    kmod-ipsec6
    kmod-sit
    kmod-ip6-tunnel
    kmod-gre
    kmod-gre6
    kmod-veth
    kmod-vrf
    kmod-macvlan
    kmod-ipvlan
    kmod-ifb
    kmod-wireguard
    kmod-ppp
    kmod-pppoe
    kmod-pppox
    kmod-pptp
    kmod-pppol2tp
    kmod-l2tp
    kmod-sctp
    kmod-mpls
    kmod-sched-core
    kmod-sched-cake
    kmod-sched-fq-pie
    kmod-sched-flower
    kmod-sched-connmark
    kmod-netem
    kmod-tcp-hybla
    kmod-tcp-scalable
    kmod-sctp-diag
    kmod-unix-diag
    kmod-packet-diag
    kmod-nf-conntrack
    kmod-nf-nat
    kmod-nf-flow
    kmod-nf-socket
    kmod-nf-tproxy
    kmod-nf-reject
    kmod-nfnetlink
    kmod-nfnetlink-log
    kmod-nfnetlink-queue
    kmod-nf-conntrack-netlink
    kmod-nft-core
    kmod-nft-arp
    kmod-nft-dup-inet
    kmod-nft-queue
    kmod-nft-compat
    kmod-nft-xfrm
    kmod-br-netfilter
    kmod-ipt-core
    kmod-ipt-filter
    kmod-ipt-nat
    kmod-ipt-conntrack
    kmod-ipt-socket
    kmod-ipt-tproxy
    kmod-ipt-extra
    kmod-ip6tables
    kmod-ip6tables-extra
    kmod-fs-btrfs
    kmod-fs-cifs
    kmod-fs-ksmbd
    kmod-fs-nfs
    kmod-fs-nfs-common
    kmod-fs-nfs-v3
    kmod-fs-nfs-v4
    kmod-fs-nfsd
    kmod-fs-squashfs
    kmod-fs-isofs
    kmod-fs-udf
    kmod-fs-jfs
    kmod-fs-minix
    kmod-fs-reiserfs
    kmod-fs-hfs
    kmod-fs-hfsplus
    kmod-fs-autofs4
    kmod-fs-configfs
    kmod-fs-9p
    kmod-fuse
    kmod-ata-core
    kmod-scsi-core
    kmod-scsi-generic
    kmod-cdrom
    kmod-loop
    kmod-nbd
    kmod-dm
    kmod-dm-raid
    kmod-md-mod
    kmod-md-raid0
    kmod-md-raid1
    kmod-md-raid10
    kmod-md-raid456
    kmod-usb-net
    kmod-usb-net-aqc111
    kmod-usb-net-asix
    kmod-usb-net-asix-ax88179
    kmod-usb-net-cdc-ether
    kmod-usb-net-cdc-ncm
    kmod-usb-net-cdc-mbim
    kmod-usb-net-qmi-wwan
    kmod-usb-net-rtl8150
    kmod-usb-net-rtl8152
    kmod-usb-net-lan78xx
    kmod-usb-serial
    kmod-usb-serial-option
    kmod-usb-serial-qualcomm
    kmod-usb-storage
    kmod-usb-storage-uas
    kmod-usb-storage-extras
    kmod-usb2
    kmod-usb3
    kmod-usb-dwc3
    kmod-usb-xhci-hcd
    kmod-usb-ehci
    kmod-usb-ohci
    kmod-fs-ext4
    kmod-fs-vfat
    kmod-fs-exfat
    kmod-fs-ntfs3
    kmod-fs-f2fs
    kmod-fs-xfs
)
for package in "${REQUIRED_KMODS[@]}"; do
    grep -qx "CONFIG_PACKAGE_${package}=y" .config || {
        echo "错误：必需内核模块 ${package} 在 make defconfig 后未被选中。" >&2
        exit 1
    }
done
echo "检查通过：网络功能与 USB/文件系统内核模块均已选中。"

REQUIRED_PACKAGES=(
    luci-nginx
    luci-theme-argon
    luci-app-quickfile
    quickfile
    nginx-ssl
    nginx-util
    nginx-mod-luci
    nginx-mod-ubus
    uwsgi
    uwsgi-luci-support
    block-mount
    ntfs3-mount
    fuse-utils
    usbutils
    sgdisk
    resize2fs
)
for package in "${REQUIRED_PACKAGES[@]}"; do
    grep -qx "CONFIG_PACKAGE_${package}=y" .config || {
        echo "错误：必需软件包 ${package} 在 make defconfig 后未被选中。" >&2
        exit 1
    }
done
echo "检查通过：QuickFile、Nginx 和存储工具均已在配置中选中。"

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

# Verify the final firmware manifest, not just the requested Kconfig selections.
MANIFEST_FILE="$(find "$FIRMWARE_DIR" -maxdepth 1 -type f -name '*.manifest' -print -quit)"
if [[ -z "$MANIFEST_FILE" ]]; then
    echo "错误：未生成固件软件包清单，无法验证本次选择的内核模块和 QuickFile 组件。" >&2
    exit 1
fi
for package in "${REQUIRED_KMODS[@]}"; do
    if ! awk -v package="$package" '$1 == package { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
        echo "错误：最终固件软件包清单缺少指定内核模块：$package" >&2
        exit 1
    fi
done
echo "检查通过：最终固件清单包含全部网络、USB 与文件系统内核模块。"

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! awk -v package="$package" '$1 == package { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
        echo "错误：最终固件软件包清单缺少必需组件：$package" >&2
        exit 1
    fi
done
echo "检查通过：OpenClash、QuickFile、Diskman、Nginx 和磁盘管理基础工具均已进入最终固件。"

if ! find "$FIRMWARE_DIR" -maxdepth 1 -type f | grep -q .; then
    echo "错误：编译流程结束，但未收集到任何固件产物。" >&2
    exit 1
fi

echo "===== 固件产物清单 ====="
find "$FIRMWARE_DIR" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
echo "===== 编译缓存已保留：$BUILD_DIR/.ccache ====="
