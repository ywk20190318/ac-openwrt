#!/usr/bin/env bash
set -Eeuo pipefail

install_luci_base() {
    echo "正在安装原版 LuCI（Nginx Web 服务）和 Argon 主题..."
    ./scripts/feeds install -p luci -f luci-nginx
    ./scripts/feeds install -p luci -f luci-theme-argon

    if [[ ! -e "$BUILD_DIR/package/feeds/luci/luci-nginx" ]]; then
        echo "错误：LuCI Nginx collection 未正确链接。" >&2
        return 1
    fi
}

install_nginx_packages() {
    echo "正在安装 QuickFile 所需的 Nginx / uWSGI 组件..."
    ./scripts/feeds install -p packages -f \
        nginx-ssl \
        nginx-util \
        nginx-mod-luci \
        nginx-mod-ubus \
        uwsgi \
        uwsgi-luci-support
}

install_quickfile() {
    local repo_url="https://github.com/sbwml/luci-app-quickfile.git"
    local commit="ef2ca5d16ad1156539930d8763c3069f6ac4eb12"
    local target_dir="$BUILD_DIR/package/quickfile"

    echo "正在准备 QuickFile（固定上游提交：$commit）..."
    mkdir -p "$BUILD_DIR/package"
    rm -rf "$target_dir"

    git clone --depth 1 "$repo_url" "$target_dir"
    git -C "$target_dir" fetch --depth 1 origin "$commit"
    git -C "$target_dir" checkout --detach "$commit"

    [[ -f "$target_dir/luci-app-quickfile/Makefile" ]] || {
        echo "错误：QuickFile LuCI Makefile 不存在。" >&2
        return 1
    }
    [[ -f "$target_dir/quickfile/Makefile" ]] || {
        echo "错误：QuickFile 后端 Makefile 不存在。" >&2
        return 1
    }

    echo "✓ QuickFile 前端和 Rust 后端源码准备完成"
}
