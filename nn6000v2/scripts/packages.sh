#!/usr/bin/env bash
set -e

GITHUB_BASE="https://github.com/"
OPENWRT_PACKAGES_DIR="$BUILD_DIR/feeds/openwrt_packages"

update_golang() {
    if [[ -d "$BUILD_DIR/feeds/packages/lang/golang" ]]; then
        rm -rf "$BUILD_DIR/feeds/packages/lang/golang"
        if ! git clone --depth 1 -b "$GOLANG_BRANCH" "$GOLANG_REPO" "$BUILD_DIR/feeds/packages/lang/golang"; then
            echo "错误：克隆 golang 仓库 $GOLANG_REPO 失败" >&2
            exit 1
        fi
        echo "✓ golang 软件包更新完成"
    fi
}

clone_packages() {
    local name="$1" repo_url="$2" target_dir="$3"
    local sparse_pattern="${4:-}" pre_cmd="${5:-}" post_cmd="${6:-}"
    local move_from="${7:-}" move_to="${8:-}" branch="${9:-}"
    local clone_args=()
    [ -z "$branch" ] || clone_args=(-b "$branch")

    [ -z "$pre_cmd" ] || (cd "$BUILD_DIR" && eval "$pre_cmd")
    rm -rf "$target_dir"
    if [ -n "$sparse_pattern" ]; then
        git clone --filter=blob:none --no-checkout "${clone_args[@]}" "$repo_url" "$target_dir"
        (
            cd "$target_dir"
            git sparse-checkout init --cone
            git sparse-checkout set $sparse_pattern
            git checkout --quiet
        )
        if [ -n "$move_from" ] && [ -n "$move_to" ]; then
            rm -rf "$move_to"
            mkdir -p "$(dirname "$move_to")"
            mv "$move_from" "$move_to"
        fi
    else
        git clone --depth=1 "${clone_args[@]}" "$repo_url" "$target_dir"
    fi
    [ -z "$post_cmd" ] || (cd "$BUILD_DIR" && eval "$post_cmd")
    echo "✓ $name 克隆完成"
}

fix_apk_pkg_version() {
    local makefile="$1"
    [ -f "$makefile" ] || { echo "Warning: 未找到 $makefile" >&2; return 0; }
    if grep -q '^PKG_VERSION:=v' "$makefile"; then
        sed -i 's/^PKG_VERSION:=v/PKG_VERSION:=/' "$makefile"
    fi
}

install_openwrt_packages() {
    ./scripts/feeds install -p openwrt_packages -f \
        luci-theme-argon luci-app-argon-config \
        luci-app-quickfile \
        luci-app-mini-diskmanager luci-app-hd-idle luci-app-p910nd
}

clone_quickfile() {
    local target="$OPENWRT_PACKAGES_DIR/luci-app-quickfile"
    local temp_dir="$OPENWRT_PACKAGES_DIR/quickfile-temp"
    clone_packages "luci-app-quickfile" \
        "${GITHUB_BASE}sbwml/luci-app-quickfile.git" \
        "$temp_dir" "luci-app-quickfile quickfile" "" \
        "mkdir -p \"$target\" && rm -rf \"$target/luci-app-quickfile\" \"$target/quickfile\" && mv \"$temp_dir/luci-app-quickfile\" \"$temp_dir/quickfile\" \"$target/\""
    rm -rf "$temp_dir"
}

clone_mini_diskmanager() {
    local temp_dir="$OPENWRT_PACKAGES_DIR/mini-diskmanager-temp"
    clone_packages "luci-app-mini-diskmanager" \
        "${GITHUB_BASE}4IceG/luci-app-mini-diskmanager.git" \
        "$temp_dir" "luci-app-mini-diskmanager" "" "" \
        "$temp_dir/luci-app-mini-diskmanager" \
        "$OPENWRT_PACKAGES_DIR/luci-app-mini-diskmanager"
    rm -rf "$temp_dir"
}

remove_attendedsysupgrade() {
    find "$BUILD_DIR/feeds/luci/collections" -name "Makefile" -print0 |
    while IFS= read -r -d '' makefile; do
        if grep -q "luci-app-attendedsysupgrade" "$makefile"; then
            sed -i '/luci-app-attendedsysupgrade/d' "$makefile"
        fi
    done
}
