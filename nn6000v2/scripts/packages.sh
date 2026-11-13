#!/usr/bin/env bash
set -Eeuo pipefail

install_luci_base() {
    echo "安装 ImmortalWrt 原版 LuCI collection..."
    ./scripts/feeds install -p luci -f luci
    ./scripts/feeds install -p luci -f luci-theme-argon
    ./scripts/feeds install -p luci -f luci-i18n-base-zh-cn

    if [[ ! -e "$BUILD_DIR/package/feeds/luci/luci" ]]; then
        echo "错误：LuCI collection 未正确链接到 package/feeds/luci/luci" >&2
        return 1
    fi
}
