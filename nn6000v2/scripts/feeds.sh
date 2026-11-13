#!/usr/bin/env bash

update_feeds() {
    local feeds_path="$BUILD_DIR/$FEEDS_CONF"

    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        feeds_path="$BUILD_DIR/feeds.conf"
    fi

    if [[ ! -f "$feeds_path" ]]; then
        echo "错误：找不到 feeds 配置：$feeds_path" >&2
        return 1
    fi

    # 清理旧的本地链接源和已明确弃用的 PassWall 源
    sed -i '/^src-link[[:space:]]/d' "$feeds_path"
    sed -i '/passwall_packages/d' "$feeds_path"
    sed -i '/passwall-packages/d' "$feeds_path"

    # QuickFile 使用 openwrt-packages feed；只安装明确指定的包，不全量安装 feed
    if ! grep -q 'openwrt-packages.git' "$feeds_path"; then
        printf '\n%s\n' \
            'src-git openwrt_packages https://github.com/kenzok8/openwrt-packages.git' \
            >> "$feeds_path"
    fi

    if [[ ! -f "$BUILD_DIR/include/bpf.mk" ]]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    echo "===== 更新官方及 QuickFile 所需 feeds ====="
    ./scripts/feeds clean
    ./scripts/feeds update -a
}

install_feeds() {
    cd "$BUILD_DIR"

    echo "===== 安装本次固件明确需要的软件包 ====="
    ./scripts/feeds update -i

    install_openwrt_packages
    install_nginx_packages

    echo "===== 指定软件包安装完成（没有全量安装第三方 feed） ====="
}
