#!/usr/bin/env bash
set -Eeuo pipefail

error_handler() {
    echo "错误：脚本第 ${BASH_LINENO[0]} 行执行失败：${BASH_COMMAND}" >&2
}
trap error_handler ERR

REPO_URL=${1:?缺少 REPO_URL}
REPO_BRANCH=${2:?缺少 REPO_BRANCH}
BUILD_DIR=${3:?缺少 BUILD_DIR}
COMMIT_HASH=${4:-none}

if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$(pwd)/$BUILD_DIR"
fi

FEEDS_CONF="feeds.conf.default"
LAN_ADDR="10.0.0.1"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BASE_PATH=${BASE_PATH:-$(dirname "$SCRIPT_DIR")}

source "$SCRIPT_DIR/general.sh"
source "$SCRIPT_DIR/feeds.sh"
source "$SCRIPT_DIR/packages.sh"
source "$SCRIPT_DIR/system.sh"

main() {
    echo "===== NN6000V2 原版系统 + NSS 网络优化 + LuCI ====="

    clone_repo
    clean_up
    reset_feeds_conf

    cd "$BUILD_DIR"

    update_feeds
    install_feeds

    # 首次启动默认配置、温度显示、LAN 与 WiFi
    fix_default_set
    update_default_lan_addr

    # 保留的系统修复
    change_dnsmasq2full
    update_dnsmasq_conf
    update_nss_diag
    update_affinity_script
    update_cpuusage
    update_script_priority
    fix_kconfig_recursive_dependency
    remove_tweaked_packages

    echo "===== 精简脚本执行完成 ====="
    echo "保留上游默认系统服务、NSS/无线/板级驱动及原版 LuCI；不额外安装第三方服务插件。防火墙使用 firewall4/nftables。"
}

main "$@"
