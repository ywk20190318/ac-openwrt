#!/usr/bin/env bash
set -Eeuo pipefail

update_feeds() {
    local feeds_path="$BUILD_DIR/$FEEDS_CONF"

    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        feeds_path="$BUILD_DIR/feeds.conf"
    fi

    if [[ ! -f "$feeds_path" ]]; then
        echo "错误：找不到 feeds 配置：$feeds_path" >&2
        return 1
    fi

    # Remove obsolete local links / retired PassWall feed entries only.
    sed -i '/^src-link[[:space:]]/d' "$feeds_path"
    sed -i '/passwall_packages/d' "$feeds_path"
    sed -i '/passwall-packages/d' "$feeds_path"

    # Keep the source's standard official feeds; do not inject third-party feeds.
    if [[ ! -f "$BUILD_DIR/include/bpf.mk" ]]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    echo "===== 更新源码默认 feeds ====="
    ./scripts/feeds clean
    ./scripts/feeds update -a
}

install_feeds() {
    cd "$BUILD_DIR"

    echo "===== 安装原版 LuCI collection ====="
    ./scripts/feeds update -i
    install_luci_base

    echo "===== 完成：只安装原版 LuCI；不额外安装服务插件 ====="
}
