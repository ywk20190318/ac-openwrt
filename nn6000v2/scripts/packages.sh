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


install_openclash() {
    local repo_url="https://github.com/vernesong/OpenClash.git"
    local commit="e553e82e01c697aefbe1555261a503f425e00ccd"
    local target_dir="$BUILD_DIR/package/openclash"

    echo "正在准备 OpenClash（固定上游提交：$commit）..."
    mkdir -p "$BUILD_DIR/package"
    rm -rf "$target_dir"
    git clone --depth 1 "$repo_url" "$target_dir"
    git -C "$target_dir" fetch --depth 1 origin "$commit"
    git -C "$target_dir" checkout --detach "$commit"

    [[ -f "$target_dir/luci-app-openclash/Makefile" ]] || {
        echo "错误：OpenClash LuCI Makefile 不存在。" >&2
        return 1
    }

    # OpenClash's Makefile calls po2lmo to build translation catalogs.
    if ! command -v po2lmo >/dev/null 2>&1; then
        echo "正在编译并安装 OpenClash 所需的 po2lmo 主机工具..."
        (cd "$target_dir/luci-app-openclash/tools/po2lmo" && make && sudo make install)
    fi
    command -v po2lmo >/dev/null 2>&1 || {
        echo "错误：po2lmo 主机工具不可用，无法构建 OpenClash 翻译。" >&2
        return 1
    }
    echo "✓ OpenClash 源码和 po2lmo 工具准备完成"
}

install_diskman() {
    local repo_url="https://github.com/lisaac/luci-app-diskman.git"
    local commit="c20df1d4f40d86e32fd919f33122b2a48f8a99b4"
    local source_dir="$BUILD_DIR/tmp-diskman-source"
    local app_dir="$BUILD_DIR/package/luci-app-diskman"
    local parted_dir="$BUILD_DIR/package/parted"

    echo "正在准备 LuCI Diskman 分区管理（固定上游提交：$commit）..."
    rm -rf "$source_dir" "$app_dir"
    git clone --depth 1 "$repo_url" "$source_dir"
    git -C "$source_dir" fetch --depth 1 origin "$commit"
    git -C "$source_dir" checkout --detach "$commit"

    [[ -f "$source_dir/applications/luci-app-diskman/Makefile" ]] || {
        echo "错误：Diskman LuCI Makefile 不存在。" >&2
        return 1
    }
    [[ -f "$source_dir/Parted.Makefile" ]] || {
        echo "错误：Diskman 配套 parted Makefile 不存在。" >&2
        return 1
    }

    install -Dm644 "$source_dir/applications/luci-app-diskman/Makefile" "$app_dir/Makefile"
    install -Dm644 "$source_dir/Parted.Makefile" "$parted_dir/Makefile"
    echo "✓ Diskman 与 parted 源码准备完成"
}
