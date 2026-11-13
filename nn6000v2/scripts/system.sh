#!/usr/bin/env bash
fix_kernel_netfilter_package_conflict() {
    local file="$BUILD_DIR/package/kernel/linux/modules/netfilter.mk"
    local patch_file="$BUILD_DIR/.nn6000v2-netfilter-fix.patch"

    [[ -f "$file" ]] || {
        echo "错误：找不到内核 netfilter 包定义：$file" >&2
        return 1
    }

    # Already fixed upstream: the legacy kmod-iptables split package is absent.
    if ! grep -q '^define KernelPackage/iptables$' "$file"; then
        echo "✓ netfilter 内核包冲突修复已存在，跳过"
        return 0
    fi

    cat > "$patch_file" <<'PATCH'
diff --git a/package/kernel/linux/modules/netfilter.mk b/package/kernel/linux/modules/netfilter.mk
index 0000000..0000000 100644
--- a/package/kernel/linux/modules/netfilter.mk
+++ b/package/kernel/linux/modules/netfilter.mk
@@ -52,30 +52,13 @@ endef
 $(eval $(call KernelPackage,nf-conncount))
 
 
-define KernelPackage/iptables
-  SUBMENU:=$(NF_MENU)
-  TITLE:=Iptables legacy
-  KCONFIG:= \
-	CONFIG_IP_NF_IPTABLES_LEGACY \
-	CONFIG_NETFILTER_XTABLES \
-	CONFIG_NETFILTER_XTABLES_LEGACY=y \
-	CONFIG_IP6_NF_IPTABLES_LEGACY \
-	CONFIG_BRIDGE_NF_EBTABLES_LEGACY
-  HIDDEN:=1
-  DEPENDS:=@!LINUX_6_12
-  FILES:= \
-	$(LINUX_DIR)/net/ipv4/netfilter/ip_tables.ko \
-	$(LINUX_DIR)/net/netfilter/x_tables.ko
-  AUTOLOAD:=$(call AutoProbe,$(notdir ip_tables x_tables))
-endef
-
-$(eval $(call KernelPackage,iptables))
-
-
 define KernelPackage/nf-ipt
   SUBMENU:=$(NF_MENU)
   TITLE:=Iptables core
-  KCONFIG:=$(KCONFIG_NF_IPT)
-  DEPENDS:=+!LINUX_6_12:kmod-iptables
+  KCONFIG:= \
+	$(KCONFIG_NF_IPT) \
+	CONFIG_IP_NF_IPTABLES_LEGACY \
+	CONFIG_NETFILTER_XTABLES_LEGACY=y
   FILES:=$(foreach mod,$(NF_IPT-m),$(LINUX_DIR)/net/$(mod).ko)
   AUTOLOAD:=$(call AutoProbe,$(notdir $(NF_IPT-m)))
 endef
@@ -86,7 +69,9 @@ $(eval $(call KernelPackage,nf-ipt))
 define KernelPackage/nf-ipt6
   SUBMENU:=$(NF_MENU)
   TITLE:=Ip6tables core
-  KCONFIG:=$(KCONFIG_NF_IPT6)
+  KCONFIG:= \
+	$(KCONFIG_NF_IPT6) \
+	CONFIG_IP6_NF_IPTABLES_LEGACY
   FILES:=$(foreach mod,$(NF_IPT6-m),$(LINUX_DIR)/net/$(mod).ko)
   AUTOLOAD:=$(call AutoProbe,$(notdir $(NF_IPT6-m)))
   DEPENDS:=+kmod-nf-ipt +kmod-nf-log6
@@ -1085,7 +1070,9 @@ define KernelPackage/ebtables
   TITLE:=Bridge firewalling modules
   DEPENDS:=+kmod-ipt-core
   FILES:=$(foreach mod,$(EBTABLES-m),$(LINUX_DIR)/net/$(mod).ko)
-  KCONFIG:=$(KCONFIG_EBTABLES)
+  KCONFIG:= \
+	$(KCONFIG_EBTABLES) \
+	CONFIG_BRIDGE_NF_EBTABLES_LEGACY
   AUTOLOAD:=$(call AutoProbe,$(notdir $(EBTABLES-m)))
 endef
PATCH

    if git -C "$BUILD_DIR" apply --check "$patch_file"; then
        git -C "$BUILD_DIR" apply "$patch_file"
        echo "✓ 已应用 OpenWrt 上游 netfilter 重复模块修复"
    else
        echo "错误：netfilter.mk 与预期上游版本不匹配，拒绝盲目修改。" >&2
        return 1
    fi
    rm -f "$patch_file"
}


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

