#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$BASE_PATH/.." && pwd)"

DEV="${1:?Usage: $0 <device_model>}"
INI_FILE="$BASE_PATH/configs/${DEV}.ini"

[[ -f "$INI_FILE" ]] || {
    echo "ERROR: device config not found: $INI_FILE" >&2
    exit 1
}

read_ini() {
    local key="$1"
    awk -F= -v key="$key" '
        $1 == key {
            sub(/^[^=]*=/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            print
            exit
        }
    ' "$INI_FILE"
}

REPO_URL="$(read_ini REPO_URL)"
REPO_BRANCH="$(read_ini REPO_BRANCH)"
REPO_BRANCH="${REPO_BRANCH:-main}"
COMMIT_HASH="$(read_ini COMMIT_HASH)"
BUILD_DIR="$REPO_ROOT/action_build"

[[ -n "$REPO_URL" ]] || {
    echo "ERROR: REPO_URL is empty in $INI_FILE" >&2
    exit 1
}

if [[ -e "$BUILD_DIR" ]]; then
    echo "ERROR: build directory already exists: $BUILD_DIR" >&2
    echo "Remove it before running pre_clone_action.sh again." >&2
    exit 1
fi

printf 'Source: %s\nBranch: %s\n' "$REPO_URL" "$REPO_BRANCH"
printf '%s\n' "$REPO_URL" "$REPO_BRANCH" "${COMMIT_HASH:-none}" > "$REPO_ROOT/repo_flag"

git clone --depth 1 --single-branch --branch "$REPO_BRANCH" "$REPO_URL" "$BUILD_DIR"

if [[ -n "$COMMIT_HASH" && "$COMMIT_HASH" != "none" ]]; then
    git -C "$BUILD_DIR" fetch --depth 1 origin "$COMMIT_HASH"
    git -C "$BUILD_DIR" checkout --detach FETCH_HEAD
fi

# The build runner uses GitHub-hosted networking; remove mainland-only mirrors
# that can be inaccessible or inconsistent from the runner.
MIRRORS_FILE="$BUILD_DIR/scripts/projectsmirrors.json"
if [[ -f "$MIRRORS_FILE" ]]; then
    sed -i '/\.cn\//d; /tencent/d; /aliyun/d' "$MIRRORS_FILE"
fi

echo "Source checkout ready: $BUILD_DIR"
