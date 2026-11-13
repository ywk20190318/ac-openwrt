#!/usr/bin/env bash

update_golang() {
    if [[ -d ./feeds/packages/lang/golang ]]; then
        \rm -rf ./feeds/packages/lang/golang
        if ! git clone --depth 1 -b "$GOLANG_BRANCH" "$GOLANG_REPO" ./feeds/packages/lang/golang; then
            echo "错误：克隆 golang 仓库 $GOLANG_REPO 失败" >&2
            exit 1
        fi
        echo "✓ golang 软件包更新完成"
    fi
}

install_openwrt_packages() {
    ./scripts/feeds install -p openwrt_packages -f \
        taskd \
        luci-lib-xterm \
        luci-lib-taskd \
        luci-lib-docker \
        luci-app-diskman \
        luci-app-dockerman \
        luci-app-quickfile
}

install_fullconenat() {
    # 安装 fullconenat 相关包
    ./scripts/feeds install -p packages -f kmod-fullconenat
}

install_diskman() {
    local path="$BUILD_DIR/feeds/openwrt_packages/luci-app-diskman"
    local repo_url="https://github.com/lisaac/luci-app-diskman.git"

    mkdir -p "$BUILD_DIR/feeds/openwrt_packages" || return
    cd "$BUILD_DIR/feeds/openwrt_packages" || return
    \rm -rf "luci-app-diskman"

    if ! git clone --filter=blob:none --no-checkout "$repo_url" diskman; then
        echo "错误：从 $repo_url 克隆 diskman 仓库失败" >&2
        exit 1
    fi

    cd diskman || return

    git sparse-checkout init --cone
    git sparse-checkout set applications/luci-app-diskman || return

    git checkout --quiet

    mv applications/luci-app-diskman ../luci-app-diskman || return
    cd .. || return
    \rm -rf diskman
    cd "$BUILD_DIR"

    sed -i 's/fs-ntfs /fs-ntfs3 /g' "$path/Makefile"
    sed -i '/ntfs-3g-utils /d' "$path/Makefile"

    echo "✓ luci-app-diskman 克隆完成"
}

_sync_luci_lib_docker() {
    local repo_url="https://github.com/lisaac/luci-lib-docker.git"
    local luci_lib_docker_dir="$BUILD_DIR/feeds/openwrt_packages/luci-lib-docker"

    mkdir -p "$BUILD_DIR/feeds/openwrt_packages" || return

    rm -rf "$luci_lib_docker_dir"
    if ! git clone --depth=1 "$repo_url" "$luci_lib_docker_dir"; then
        echo "错误：从 $repo_url 克隆 luci-lib-docker 仓库失败" >&2
        exit 1
    fi

    echo "✓ luci-lib-docker 克隆完成"
}

install_dockerman() {
    local path="$BUILD_DIR/feeds/openwrt_packages/luci-app-dockerman"
    local repo_url="https://github.com/wzdddyy/luci-app-dockerman.git"

    _sync_luci_lib_docker || return

    mkdir -p "$BUILD_DIR/feeds/openwrt_packages" || return
    cd "$BUILD_DIR/feeds/openwrt_packages" || return
    \rm -rf "luci-app-dockerman"

    if ! git clone --filter=blob:none --no-checkout "$repo_url" dockerman; then
        echo "错误：从 $repo_url 克隆 dockerman 仓库失败" >&2
        exit 1
    fi

    cd dockerman || return

    git sparse-checkout init --cone
    git sparse-checkout set applications/luci-app-dockerman || return

    git checkout --quiet

    mv applications/luci-app-dockerman ../luci-app-dockerman || return
    cd .. || return
    \rm -rf dockerman
    cd "$BUILD_DIR"

    echo "✓ luci-app-dockerman 克隆完成"
}

install_quickfile() {
    local repo_url="https://github.com/sbwml/luci-app-quickfile.git"
    local target_dir="$BUILD_DIR/feeds/openwrt_packages/luci-app-quickfile"

    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi

    if ! git clone --depth 1 "$repo_url" "$target_dir"; then
        echo "错误：从 $repo_url 克隆 luci-app-quickfile 仓库失败" >&2
        exit 1
    fi

    echo "✓ luci-app-quickfile 克隆完成"
}

remove_attendedsysupgrade() {
    find "$BUILD_DIR/feeds/luci/collections" -name "Makefile" | while read -r makefile; do
        if grep -q "luci-app-attendedsysupgrade" "$makefile"; then
            sed -i "/luci-app-attendedsysupgrade/d" "$makefile"
            echo "Removed luci-app-attendedsysupgrade from $makefile"
        fi
    done
}
