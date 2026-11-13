#!/usr/bin/env bash

install_openwrt_packages() {
    echo "安装 QuickFile 及其必要依赖..."
    ./scripts/feeds install -p openwrt_packages -f \
        taskd \
        luci-lib-xterm \
        luci-lib-taskd \
        luci-app-quickfile
}

install_nginx_packages() {
    echo "安装 Nginx HTTP + LuCI 运行组件..."
    ./scripts/feeds install -p packages -f \
        nginx-ssl \
        nginx-util \
        nginx-mod-luci \
        nginx-mod-ubus \
        uwsgi \
        uwsgi-luci-support
}

install_docker_packages() {
    echo "安装 Docker Engine、运行时和 Dockerman 管理界面..."
    # Runtime packages are supplied by the OpenWrt packages feed.
    ./scripts/feeds install -p packages -f \
        docker \
        dockerd \
        containerd \
        runc \
        docker-compose \
        cgroupfs-mount

    # Dockerman LuCI application and its libraries are supplied by the LuCI feed.
    ./scripts/feeds install -p luci -f \
        luci-app-dockerman \
        luci-lib-docker \
        luci-compat \
        ttyd
}

install_quickfile() {
    local repo_url="https://github.com/sbwml/luci-app-quickfile.git"
    local target_dir="$BUILD_DIR/feeds/openwrt_packages/luci-app-quickfile"

    mkdir -p "$BUILD_DIR/feeds/openwrt_packages"
    rm -rf "$target_dir"

    if ! git clone --depth 1 "$repo_url" "$target_dir"; then
        echo "错误：克隆 QuickFile 失败：$repo_url" >&2
        return 1
    fi

    echo "✓ QuickFile 源码准备完成"
}
