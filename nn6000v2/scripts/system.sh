#!/usr/bin/env bash
fix_default_set() {
    local defaults_dir="$BUILD_DIR/package/base-files/files/etc/uci-defaults"

    install -Dm755 "$BASE_PATH/patches/991_custom_settings" \
        "$defaults_dir/991_custom_settings"
    install -Dm755 "$BASE_PATH/patches/992_set-wifi-uci.sh" \
        "$defaults_dir/992_set-wifi-uci.sh"

    if [[ -f "$BASE_PATH/patches/993_set_pppoe.sh" ]]; then
        install -Dm755 "$BASE_PATH/patches/993_set_pppoe.sh" \
            "$defaults_dir/993_set_pppoe.sh"
    fi

    # NN6000V2 温度显示：沿用 Autocore 状态页读取 tempinfo 的方式
    local autocore_temp="$BUILD_DIR/package/emortal/autocore/files/tempinfo"
    if [[ -f "$autocore_temp" && -f "$BASE_PATH/patches/tempinfo" ]]; then
        install -Dm755 "$BASE_PATH/patches/tempinfo" "$autocore_temp"
        echo "✓ 已更新 Autocore 温度读取脚本"
    else
        echo "警告：未找到 Autocore 的 tempinfo 目标文件；请确认当前源码包含 Autocore，否则 LuCI 温度显示不会生效。" >&2
    fi
}

change_dnsmasq2full() {
    local target_mk="$BUILD_DIR/include/target.mk"
    if [[ -f "$target_mk" ]] && ! grep -q 'dnsmasq-full' "$target_mk"; then
        sed -i 's/\<dnsmasq\>/dnsmasq-full/g' "$target_mk"
    fi
}

update_default_lan_addr() {
    local config_generate="$BUILD_DIR/package/base-files/files/bin/config_generate"
    if [[ -f "$config_generate" ]]; then
        sed -i "s/192\\.168\\.[0-9]*\\.[0-9]*/$LAN_ADDR/g" "$config_generate"
    fi
}

update_affinity_script() {
    local target_dir="$BUILD_DIR/target/linux/qualcommax"
    local patch_file="$BASE_PATH/patches/smp_affinity"

    if [[ -d "$target_dir" && -f "$patch_file" ]]; then
        find "$target_dir" -name "set-irq-affinity" -delete
        find "$target_dir" -name "smp_affinity" -delete
        install -Dm755 "$patch_file" \
            "$target_dir/base-files/etc/init.d/smp_affinity"
    fi
}

update_nss_diag() {
    local target_file="$BUILD_DIR/package/base-files/files/usr/bin/nss_diag.sh"
    local source_file="$BASE_PATH/patches/nss_diag.sh"

    if [[ ! -f "$source_file" ]]; then
        echo "错误：缺少 $source_file" >&2
        return 1
    fi

    install -Dm755 "$source_file" "$target_file"
    echo "✓ 已保留 NSS 诊断脚本"
}

update_dnsmasq_conf() {
    local file="$BUILD_DIR/package/network/services/dnsmasq/files/dhcp.conf"

    if [[ -f "$file" ]]; then
        sed -i '/dns_redirect/d' "$file"
        echo "✓ 已保留 dnsmasq 配置修正"
    fi
}

update_script_priority() {
    local nss_init="$BUILD_DIR/package/feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
    local pbuf_init="$BUILD_DIR/package/kernel/mac80211/files/qca-nss-pbuf.init"

    if [[ -f "$nss_init" ]]; then
        sed -i 's/^START=.*/START=88/' "$nss_init"
    fi

    if [[ -f "$pbuf_init" ]]; then
        sed -i 's/^START=.*/START=89/' "$pbuf_init"
    fi
}

fix_kconfig_recursive_dependency() {
    local file="$BUILD_DIR/scripts/package-metadata.pl"

    if [[ -f "$file" ]]; then
        sed -i 's/<PACKAGE_\$pkgname/!=y/g' "$file"
        echo "✓ 已应用 Kconfig 递归依赖修正"
    fi
}

remove_tweaked_packages() {
    local target_mk="$BUILD_DIR/include/target.mk"

    if [[ -f "$target_mk" ]] &&
       grep -q '^DEFAULT_PACKAGES += $(DEFAULT_PACKAGES.tweak)' "$target_mk"; then
        sed -i \
            's/^DEFAULT_PACKAGES += $(DEFAULT_PACKAGES.tweak)/# DEFAULT_PACKAGES += $(DEFAULT_PACKAGES.tweak)/' \
            "$target_mk"
    fi
}

