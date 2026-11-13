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

update_nginx_ubus_module() {
    local makefile="$BUILD_DIR/feeds/packages/net/nginx/Makefile"

    local source_date="2024-03-02"
    local source_version="564fa3e9c2b04ea298ea659b793480415da26415"
    local mirror_hash="92c9ab94d88a2fe8d7d1e8a15d15cfc4d529fdc357ed96d22b65d5da3dd24d7f"

    if [[ -f "$makefile" ]]; then
        sed -i \
            -e "s/SOURCE_DATE:=2020-09-06/SOURCE_DATE:=$source_date/g" \
            -e "s/SOURCE_VERSION:=b2d7260dcb428b2fb65540edb28d7538602b4a26/SOURCE_VERSION:=$source_version/g" \
            -e "s/MIRROR_HASH:=515bb9d355ad80916f594046a45c190a68fb6554d6795a54ca15cab8bdd12fda/MIRROR_HASH:=$mirror_hash/g" \
            "$makefile"
    else
        echo "警告：未找到 Nginx Makefile，跳过 ubus 模块版本修正。" >&2
    fi
}

fix_nginx_configure() {
    local makefile="$BUILD_DIR/feeds/packages/net/nginx/Makefile"

    if [[ -f "$makefile" ]]; then
        sed -i \
            -e 's/--target=[^ ]*[[:space:]]//g' \
            -e 's/--host=[^ ]*[[:space:]]//g' \
            -e 's/--disable-dependency-tracking[[:space:]]//g' \
            -e 's/--program-prefix=[^ ]*[[:space:]]//g' \
            -e 's/--program-suffix=[^ ]*[[:space:]]//g' \
            "$makefile"
    fi
}

set_nginx_default_config() {
    local nginx_config="$BUILD_DIR/feeds/packages/net/nginx-util/files/nginx.config"

    if [[ -f "$nginx_config" ]]; then
        # 只监听 HTTP/80，不生成 HTTPS/443 监听项
        cat > "$nginx_config" <<'EOF'
config main 'global'
        option uci_enable 'true'

config server 'http_only'
        list listen '80'
        list listen '[::]:80'
        option server_name '_lan'
        list include 'restrict_locally'
        list include 'conf.d/*.locations'
        option access_log 'off; # logd openwrt'
EOF
        echo "✓ Nginx 已设置为 HTTP only"
    else
        echo "警告：未找到 nginx-util 配置模板：$nginx_config" >&2
    fi

    local nginx_template="$BUILD_DIR/feeds/packages/net/nginx-util/files/uci.conf.template"
    if [[ -f "$nginx_template" ]] &&
       ! grep -q 'client_body_in_file_only clean;' "$nginx_template"; then
        sed -i '/client_max_body_size 128M;/a\
\tclient_body_in_file_only clean;\
\tclient_body_temp_path /mnt/tmp;' "$nginx_template"
    fi

    local luci_support="$BUILD_DIR/feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support"
    if [[ -f "$luci_support" ]] &&
       ! grep -q 'client_body_in_file_only off;' "$luci_support"; then
        sed -i '/ubus_parallel_req 2;/a\
        client_body_in_file_only off;\
        client_max_body_size 1M;' "$luci_support"
    fi
}

update_uwsgi_limit_as() {
    local cgi_ini="$BUILD_DIR/feeds/packages/net/uwsgi/files-luci-support/luci-cgi_io.ini"
    local webui_ini="$BUILD_DIR/feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini"

    [[ ! -f "$cgi_ini" ]] || sed -i 's/^limit-as = .*/limit-as = 8192/' "$cgi_ini"
    [[ ! -f "$webui_ini" ]] || sed -i 's/^limit-as = .*/limit-as = 8192/' "$webui_ini"
}
