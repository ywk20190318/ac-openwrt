
#!/usr/bin/env bash
set -e
set -o errexit
set -o errtrace

error_handler() {
    echo "Error occurred in script at line: ${BASH_LINENO[0]}, command: '${BASH_COMMAND}'"
}

trap 'error_handler' ERR

REPO_URL=$1
REPO_BRANCH=$2
BUILD_DIR=$3
COMMIT_HASH=$4

# Convert BUILD_DIR to absolute path
if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$(pwd)/$BUILD_DIR"
fi

FEEDS_CONF="feeds.conf.default"
GOLANG_REPO="https://github.com/sbwml/packages_lang_golang"
GOLANG_BRANCH="26.x"

# 使用 OpenWrt 默认 Bootstrap 主题
THEME_SET="bootstrap"

LAN_ADDR="10.0.0.1"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BASE_PATH=${BASE_PATH:-$(dirname "$SCRIPT_DIR")}

source "$SCRIPT_DIR/general.sh"
source "$SCRIPT_DIR/feeds.sh"
source "$SCRIPT_DIR/packages.sh"
source "$SCRIPT_DIR/system.sh"
source "$SCRIPT_DIR/docker.sh"

main() {
    # 基础仓库与编译环境
    clone_repo
    clean_up
    reset_feeds_conf
    update_feeds
    update_golang

    # 保留的第三方功能
    install_quickfile
    install_diskman
    install_dockerman
    install_adguardhome
    install_easytier
    install_oaf

    # 安装软件源软件包
    install_feeds

    # Docker
    update_docker_stack

    # 系统默认配置
    remove_tweaked_packages
    fix_default_set
    fix_miniupnpd
    change_dnsmasq2full
    fix_mk_def_depends
    update_default_lan_addr
    update_affinity_script
    update_dnsmasq_conf
    change_cpuusage
    set_custom_task

    # NSS 与系统性能
    update_nss_pbuf_performance
    update_nss_diag
    fix_compile_coremark

    # 固件信息与升级配置
    set_build_signature
    add_backup_info_to_sysupgrade
    remove_attendedsysupgrade
    fix_kconfig_recursive_dependency

    # Nginx Web 管理
    set_nginx_default_config
    update_nginx_ubus_module
    fix_nginx_configure
    update_uwsgi_limit_as

    # 系统及驱动修复
    update_script_priority
    fix_openssl_ktls
    fix_opkg_check
    fix_quectel_cm

    # PBR 多线路支持
    install_pbr_isp
    fix_pbr_ip_forward
}

main "$@"
