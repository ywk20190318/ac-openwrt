#!/usr/bin/env bash

set -e

# Determine nn6000v2 path
if [ -d "nn6000v2" ]; then
    NN6000V2_PATH="nn6000v2"
elif [ -d "../nn6000v2" ]; then
    NN6000V2_PATH="../nn6000v2"
else
    echo "Error: nn6000v2 directory not found!"
    exit 1
fi

BASE_PATH=$(cd "$NN6000V2_PATH" && pwd)

Dev=${1:?Usage: build.sh <device-config> [debug]}
Build_Mod=${2:-release}

case "$Dev" in
    *nowifi*)
        echo "Error: NoWiFi firmware targets are disabled; build the WiFi-enabled device only." >&2
        exit 1
        ;;
esac

CONFIG_FILE="$BASE_PATH/configs/$Dev.config"

if [[ ! -f $CONFIG_FILE ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi

# Use environment variables or defaults for repo config
REPO_URL=${REPO_URL:-https://github.com/VIKINGYFY/immortalwrt.git}
REPO_BRANCH=${REPO_BRANCH:-main}
BUILD_DIR=${BUILD_DIR:-imm-nss}
COMMIT_HASH=${COMMIT_HASH:-none}

configure_nginx_webserver() {
    local luci_makefile_path="$BASE_PATH/../$BUILD_DIR/feeds/luci/collections/luci/Makefile"

    if [ ! -f "$luci_makefile_path" ]; then
        echo "Error: LuCI collection Makefile not found: $luci_makefile_path" >&2
        return 1
    fi

    if grep -q '+luci-light' "$luci_makefile_path"; then
        sed -i 's/+luci-light/+luci-nginx/g' "$luci_makefile_path"
    elif ! grep -q '+luci-nginx' "$luci_makefile_path"; then
        echo "Error: cannot identify the LuCI webserver collection dependency." >&2
        return 1
    fi

    echo "LuCI collection configured to use Nginx instead of uhttpd."
}

verify_nginx_webserver_config() {
    local config_path="$BASE_PATH/../$BUILD_DIR/.config"
    local package

    for package in luci-nginx nginx-ssl nginx-mod-luci nginx-mod-ubus uwsgi uwsgi-luci-support; do
        if ! grep -q "^CONFIG_PACKAGE_${package}=y$" "$config_path"; then
            echo "Error: required Nginx/LuCI package is missing after defconfig: $package" >&2
            return 1
        fi
    done

    if grep -Eq '^CONFIG_PACKAGE_(uhttpd|uhttpd-mod-[^=]+)=y$' "$config_path"; then
        echo "Error: uhttpd or one of its modules is still selected." >&2
        grep -E '^CONFIG_PACKAGE_(uhttpd|uhttpd-mod-[^=]+)=y$' "$config_path" >&2
        return 1
    fi

    if grep -q '^CONFIG_PACKAGE_luci-light=y$' "$config_path"; then
        echo "Error: luci-light is still selected and may reintroduce uhttpd." >&2
        return 1
    fi

    echo "Nginx/LuCI package dependency checks passed; uhttpd packages are disabled."
}

verify_wifi_packages_config() {
    local config_path="$BASE_PATH/../$BUILD_DIR/.config"
    local package
    for package in kmod-ath kmod-ath11k kmod-ath11k-ahb ath11k-firmware-ipq6018-ddwrt ath11k-firmware-qcn9074-ddwrt; do
        if ! grep -q "^CONFIG_PACKAGE_${package}=y$" "$config_path"; then
            echo "Error: required Wi-Fi driver/firmware package is missing after defconfig: $package" >&2
            return 1
        fi
    done
    echo "Wi-Fi driver and firmware package checks passed."
}

verify_kernel_partition_size() {
    local image_mk="$BASE_PATH/../$BUILD_DIR/target/linux/qualcommax/image/ipq60xx.mk"
    [ -f "$image_mk" ] || { echo "Missing target image definition: $image_mk" >&2; return 1; }
    local kernel_limit_kib=12288
    local hlos_slot_kib=32768
    [ "$kernel_limit_kib" -lt "$hlos_slot_kib" ] || {
        echo "Error: configured kernel image limit exceeds the HLOS slot capacity." >&2
        return 1
    }
    sed -n '/link_nn6000-common/,/endef/p' "$image_mk" | grep -q 'KERNEL_SIZE := 12288k' || {
        echo "Error: Link NN6000 kernel partition must be 12288k (12 MiB)." >&2
        return 1
    }
    echo "Link NN6000 kernel image limit verified: 12288k within 32768k HLOS slot."
}

preflight_sonic_fullcone() {
    local config_path="$BASE_PATH/../$BUILD_DIR/.config"
    local fw4_patch="package/network/config/firewall4/patches/002-independent-ipv6.patch"
    local luci_patch="package/feeds/luci/luci-app-firewall/patches/002-independent-ipv6.patch"
    local required

    for required in \
        984-add-sonic-fullcone-support.patch \
        986-add-sonic-fullcone-to-nft.patch \
        987-sonic-fullcone-fix-races-and-drops.patch; do
        [ -s "$BASE_PATH/patches/fullcone/kernel/$required" ] || {
            echo "Missing SONiC FullCone kernel patch: $required" >&2
            return 1
        }
    done

    grep -q '^CONFIG_PACKAGE_kmod-nft-nat=y$' "$config_path" || {
        echo "kmod-nft-nat is required for SONiC FullCone." >&2
        return 1
    }
    for required in kmod-nf-nat6 kmod-nf-log6 kmod-nf-reject6; do
        grep -q "^CONFIG_PACKAGE_${required}=y$" "$config_path" || {
            echo "Required IPv6 netfilter package is missing: ${required}" >&2
            return 1
        }
    done
    if grep -Eq '^CONFIG_PACKAGE_kmod-(nft-fullcone|nft-nat6)=y$' "$config_path"; then
        echo "Obsolete standalone FullCone or invalid nft-nat6 package remains selected." >&2
        return 1
    fi
    [ -s "$fw4_patch" ] && grep -q 'fullcone6: \[ "bool", "0" \]' "$fw4_patch" || {
        echo "firewall4 patch lacks the independent IPv6 global gate." >&2
        return 1
    }
    [ -s "$luci_patch" ] && grep -q "fullcone6" "$luci_patch" || {
        echo "LuCI patch lacks the independent IPv6 control." >&2
        return 1
    }
    echo "SONiC FullCone static preflight passed."
}

apply_config() {
    \cp -f "$CONFIG_FILE" "$BASE_PATH/../$BUILD_DIR/.config"

    cat "$BASE_PATH/configs/docker_deps.config" >> "$BASE_PATH/../$BUILD_DIR/.config"
}

fix_netfilter_kmod_clash() {
    local include_netfilter_mk="$BASE_PATH/../$BUILD_DIR/include/netfilter.mk"
    local netfilter_mk="$BASE_PATH/../$BUILD_DIR/package/kernel/linux/modules/netfilter.mk"

    if [ ! -f "$include_netfilter_mk" ]; then
        echo "Netfilter include file not found: $include_netfilter_mk" >&2
        return 1
    fi

    if [ ! -f "$netfilter_mk" ]; then
        echo "Netfilter makefile not found: $netfilter_mk" >&2
        return 1
    fi

    if grep -q 'CONFIG_IP_NF_IPTABLES_LEGACY, $(P_V4)ip_tables, ge 6.12' "$include_netfilter_mk" && \
       grep -q 'CONFIG_IP6_NF_IPTABLES_LEGACY, $(P_V6)ip6_tables, ge 6.12' "$include_netfilter_mk" && \
       grep -q 'DEPENDS:=+(!(LINUX_6_12||LINUX_6_18)):kmod-iptables' "$netfilter_mk"; then
        echo "Netfilter kmod clash workaround already applied"
        return 0
    fi

    if grep -q '$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES, $(P_V4)ip_tables),))' "$include_netfilter_mk"; then
        echo "Updating NF_IPT mapping for Linux 6.12/6.18..."
        sed -i 's@$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES, $(P_V4)ip_tables),))@$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES, $(P_V4)ip_tables, lt 6.12),))@' "$include_netfilter_mk"
        sed -i '/CONFIG_IP_NF_IPTABLES, $(P_V4)ip_tables, lt 6\.12)/a$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES_LEGACY, $(P_V4)ip_tables, ge 6.12),))' "$include_netfilter_mk"
    fi

    if grep -q '$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_CORE,CONFIG_IP_NF_IPTABLES, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET)))' "$include_netfilter_mk"; then
        echo "Updating IPT_CORE userland mapping for Linux 6.12/6.18..."
        sed -i 's@$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_CORE,CONFIG_IP_NF_IPTABLES, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET)))@$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_CORE,CONFIG_IP_NF_IPTABLES, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET, lt 6.12)))@' "$include_netfilter_mk"
        sed -i '/CONFIG_IP_NF_IPTABLES, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET, lt 6\.12))/a$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_CORE,CONFIG_IP_NF_IPTABLES_LEGACY, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET, ge 6.12)))' "$include_netfilter_mk"
    fi

    if grep -q '$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT6,CONFIG_IP6_NF_IPTABLES, $(P_V6)ip6_tables),))' "$include_netfilter_mk"; then
        echo "Updating NF_IPT6 mapping for Linux 6.12/6.18..."
        sed -i 's@$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT6,CONFIG_IP6_NF_IPTABLES, $(P_V6)ip6_tables),))@$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT6,CONFIG_IP6_NF_IPTABLES, $(P_V6)ip6_tables, lt 6.12),))@' "$include_netfilter_mk"
        sed -i '/CONFIG_IP6_NF_IPTABLES, $(P_V6)ip6_tables, lt 6\.12)/a$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT6,CONFIG_IP6_NF_IPTABLES_LEGACY, $(P_V6)ip6_tables, ge 6.12),))' "$include_netfilter_mk"
    fi

    if grep -q '$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_IPV6,CONFIG_IP6_NF_IPTABLES, ip6t_icmp6)))' "$include_netfilter_mk"; then
        echo "Updating IPT_IPV6 userland mapping for Linux 6.12/6.18..."
        sed -i 's@$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_IPV6,CONFIG_IP6_NF_IPTABLES, ip6t_icmp6)))@$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_IPV6,CONFIG_IP6_NF_IPTABLES, ip6t_icmp6, lt 6.12)))@' "$include_netfilter_mk"
        sed -i '/CONFIG_IP6_NF_IPTABLES, ip6t_icmp6, lt 6\.12))/a$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_IPV6,CONFIG_IP6_NF_IPTABLES_LEGACY, ip6t_icmp6, ge 6.12)))' "$include_netfilter_mk"
    fi

    if grep -q 'DEPENDS:=+!LINUX_6_12:kmod-iptables' "$netfilter_mk"; then
        echo "Applying netfilter kmod clash workaround for Linux 6.12/6.18..."
        sed -i 's/DEPENDS:=+!LINUX_6_12:kmod-iptables/DEPENDS:=+(!(LINUX_6_12||LINUX_6_18)):kmod-iptables/' "$netfilter_mk"
        return 0
    fi

    echo "Netfilter kmod clash workaround applied successfully"
}

if [[ -d action_build ]]; then
    BUILD_DIR="action_build"
fi

"$BASE_PATH/scripts/update.sh" "$REPO_URL" "$REPO_BRANCH" "$BUILD_DIR" "$COMMIT_HASH"

apply_config
fix_netfilter_kmod_clash
configure_nginx_webserver

# Modify kernel size to 12MB for ipq60xx devices
modify_kernel_size() {
    local ipq60xx_mk_path="$BASE_PATH/../$BUILD_DIR/target/linux/qualcommax/image/ipq60xx.mk"
    
    if [ -f "$ipq60xx_mk_path" ]; then
        # Change KERNEL_SIZE from 6144k to 12288k for link_nn6000 devices
        if ! sed -n '/link_nn6000-common/,/endef/p' "$ipq60xx_mk_path" | grep -q 'KERNEL_SIZE := 12288k'; then
            sed -i '/link_nn6000-common/,/endef/{s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g}' "$ipq60xx_mk_path"
        fi
        if ! sed -n '/link_nn6000-common/,/endef/p' "$ipq60xx_mk_path" | grep -q 'KERNEL_SIZE := 12288k'; then
            echo "Error: failed to set Link NN6000 kernel size to 12288k." >&2
            return 1
        fi
        echo "Verified KERNEL_SIZE=12288k (12 MiB) for link_nn6000 devices"
    fi
}

modify_kernel_size

cd "$BASE_PATH/../$BUILD_DIR"
make defconfig
verify_nginx_webserver_config
verify_wifi_packages_config
verify_kernel_partition_size
preflight_sonic_fullcone

# Validate all selected patch series before starting the full build.
make target/linux/prepare
make package/libs/libnftnl/prepare
make package/network/utils/nftables/prepare
make package/network/config/firewall4/prepare
make package/feeds/luci/luci-app-firewall/prepare

if [[ $Build_Mod == "debug" ]]; then
    exit 0
fi

TARGET_DIR="$BASE_PATH/../$BUILD_DIR/bin/targets"
if [[ -d $TARGET_DIR ]]; then
    find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \) -exec rm -f {} +
fi

make download -j$(($(nproc) * 2))
make -j$(($(nproc) + 1)) || make -j1 V=s

if [[ -d action_build ]]; then
    make clean
fi

# Publish only the Wi-Fi-enabled build.
FIRMWARE_DIR="$BASE_PATH/../firmware"
\rm -rf "$FIRMWARE_DIR"
mkdir -p "$FIRMWARE_DIR"
find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \) -exec cp -f {} "$FIRMWARE_DIR/" \;

if find "$FIRMWARE_DIR" -maxdepth 1 -type f -iname '*nowifi*' | grep -q .; then
    echo "Error: NoWiFi artifact detected in firmware output." >&2
    exit 1
fi

echo "Wi-Fi-enabled firmware copied to: $FIRMWARE_DIR"

if [[ -d action_build ]]; then
    make clean
fi
