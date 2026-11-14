#!/usr/bin/env bash
set_nginx_default_config() {
    local nginx_config="$BUILD_DIR/feeds/packages/net/nginx-util/files/nginx.config"

    [[ -f "$nginx_config" ]] || {
        echo "错误：找不到 Nginx UCI 配置模板：$nginx_config" >&2
        return 1
    }

    # QuickFile uses Nginx as its reverse proxy. Keep LuCI and QuickFile on HTTP/80;
    # do not generate a second HTTPS redirect listener.
    cat > "$nginx_config" <<'EOF'
config main 'global'
        option uci_enable 'true'

config server 'http_only'
        list listen '80 default_server'
        list listen '[::]:80 default_server'
        option server_name '_lan'
        list include 'restrict_locally'
        list include 'conf.d/*.locations'
        option access_log 'off; # logd openwrt'
EOF

    echo "✓ Nginx 已配置为 HTTP only，并加载 QuickFile locations"
}

fix_default_set() {
    local defaults_dir="$BUILD_DIR/package/base-files/files/etc/uci-defaults"

    if [[ -f "$BASE_PATH/patches/990_set_argon_primary" ]]; then
        install -Dm755 "$BASE_PATH/patches/990_set_argon_primary" \
            "$defaults_dir/990_set_argon_primary"
    fi

    install -Dm755 "$BASE_PATH/patches/991_custom_settings" \
        "$defaults_dir/991_custom_settings"
    install -Dm755 "$BASE_PATH/patches/992_set-wifi-uci.sh" \
        "$defaults_dir/992_set-wifi-uci.sh"

    # LuCI 默认使用简体中文；同时保留用户后续在界面中修改语言的能力。
    if [[ -f "$BASE_PATH/patches/994_set_luci_zh_cn" ]]; then
        install -Dm755 "$BASE_PATH/patches/994_set_luci_zh_cn" \
            "$defaults_dir/994_set_luci_zh_cn"
    fi

    # APK feeds use the NJU mirror for mainland-China accessibility.
    if [[ -f "$BASE_PATH/patches/995_set_apk_mirror" ]]; then
        install -Dm755 "$BASE_PATH/patches/995_set_apk_mirror" \
            "$defaults_dir/995_set_apk_mirror"
    fi

    # Enable nftables FullCone NAT globally and on every masquerading zone.
    if [[ -f "$BASE_PATH/patches/996_enable_fullcone_nat" ]]; then
        install -Dm755 "$BASE_PATH/patches/996_enable_fullcone_nat" \
            "$defaults_dir/996_enable_fullcone_nat"
    fi

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


# NN6000V2 (Qualcomm IPQ60xx) LuCI CPU/NSS/ECM status
update_cpuusage() {
    local luci_rpc_path="$BUILD_DIR/feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci"
    local qualcommax_sbin_dir="$BUILD_DIR/target/linux/qualcommax/base-files/sbin"

    if [ -f "$luci_rpc_path" ]; then
        sed -i "s#const fd = popen('top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\'')#const cpuUsageCommand = access('/sbin/cpuusage') ? '/sbin/cpuusage' : 'top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\''#g" "$luci_rpc_path"
        sed -i '/cpuUsageCommand/a \\t\t\tconst fd = popen(cpuUsageCommand);' "$luci_rpc_path"
    fi

    local old_script_path="$BUILD_DIR/package/base-files/files/sbin/cpuusage"
    if [ -f "$old_script_path" ]; then
        rm -f "$old_script_path"
    fi

    if [ -d "$BUILD_DIR/target/linux/qualcommax" ]; then
        install -Dm755 "$BASE_PATH/patches/cpuusage" "$qualcommax_sbin_dir/cpuusage"
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

