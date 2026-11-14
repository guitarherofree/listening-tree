# shellcheck shell=bash
# Shared helpers for the scripts in scripts/. Source this file; don't run it.
# Works with macOS's bash 3.2 as well as newer shells.
# shellcheck disable=SC2034  # variables here are used by the scripts that source this file

set -euo pipefail

LT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export LT_ROOT

# shellcheck source=../../config/app.env
. "$LT_ROOT/config/app.env"
# shellcheck source=../../config/upstream.env
. "$LT_ROOT/config/upstream.env"
LT_VERSION="$(tr -d ' \t\r\n' < "$LT_ROOT/VERSION")"

WORK_DIR="$LT_ROOT/work"
SRC_DIR="$WORK_DIR/audacity"        # upstream Audacity + patches (a git repository)
TOOLS_DIR="$LT_ROOT/.tools"         # Python venv (cmake, ninja, aqt), Qt, gh
DIST_DIR="$LT_ROOT/dist"            # packaged releases

QT_DIR="${LT_QT_DIR:-$TOOLS_DIR/Qt/$QT_VERSION/macos}"

# Bundle names: CMake installs "audacity.app"; packages ship "<APP_NAME>.app".
BUILT_APP_NAME="audacity.app"
APP_BUNDLE_NAME="$APP_NAME.app"

# Commits in work/audacity are local bookkeeping only (they become patch files),
# so never sign them and give them a fixed identity.
GIT_WORK_FLAGS=(-c user.name="Listening Tree" -c user.email="listening-tree@localhost"
                -c commit.gpgsign=false -c tag.gpgsign=false -c core.autocrlf=false
                -c advice.detachedHead=false)

if [ -t 1 ]; then
    _c_bold=$'\033[1m'; _c_red=$'\033[31m'; _c_yellow=$'\033[33m'; _c_green=$'\033[32m'; _c_off=$'\033[0m'
else
    _c_bold=""; _c_red=""; _c_yellow=""; _c_green=""; _c_off=""
fi

info()  { printf '%s==>%s %s\n' "$_c_bold" "$_c_off" "$*"; }
ok()    { printf '%s✓%s %s\n' "$_c_green" "$_c_off" "$*"; }
warn()  { printf '%swarning:%s %s\n' "$_c_yellow" "$_c_off" "$*" >&2; }
die()   { printf '%serror:%s %s\n' "$_c_red" "$_c_off" "$*" >&2; exit 1; }

is_macos() { [ "$(uname -s)" = "Darwin" ]; }

# git in the upstream working copy (or a submodule of it)
wgit()  { git "${GIT_WORK_FLAGS[@]}" -C "$SRC_DIR" "$@"; }
mgit()  { git "${GIT_WORK_FLAGS[@]}" -C "$SRC_DIR/muse" "$@"; }

host_arch() {
    case "$(uname -m)" in
        arm64|aarch64) echo arm64 ;;
        *) echo x86_64 ;;
    esac
}

# Put the tools installed by scripts/bootstrap.sh first on PATH.
use_tools() {
    if [ -d "$TOOLS_DIR/venv/bin" ]; then PATH="$TOOLS_DIR/venv/bin:$PATH"; fi
    if [ -d "$TOOLS_DIR/bin" ]; then PATH="$TOOLS_DIR/bin:$PATH"; fi
    export PATH
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' not found. ${2:-Run scripts/bootstrap.sh first.}"
}

# Checksum of everything that defines the patched source tree. prepare-source.sh
# stores it after applying patches so it can tell when work/audacity is stale.
patches_fingerprint() {
    (
        cd "$LT_ROOT"
        printf '%s\n' "$AUDACITY_COMMIT"
        for d in patches branding/overlay; do
            [ -d "$d" ] && find "$d" -type f
        done | LC_ALL=C sort | while read -r f; do
            printf '%s ' "$f"; shasum -a 256 < "$f" 2>/dev/null || sha256sum < "$f"
        done
        true
    ) | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1
}

# Release notes for a version, taken from CHANGELOG.md (the text under "## [x.y.z]").
release_notes() {
    local version="$1"
    awk -v v="$version" '
        BEGIN { want = "## [" v "]" }
        index($0, want) == 1 { found = 1; next }
        found && /^## / { exit }
        found { print }
    ' "$LT_ROOT/CHANGELOG.md" | sed -e '/./,$!d' | awk '{ lines[NR] = $0 } END { n = NR; while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }'
}

semver_ok() {
    printf '%s' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+(\.[0-9]+)?)?$'
}

# Exit status 0 when $1 is a strictly higher version than $2 (pre-release suffixes sort before the release).
version_gt() {
    python3 - "$1" "$2" <<'PY'
import re, sys
def key(v):
    m = re.match(r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z]+)(?:\.(\d+))?)?$', v)
    if not m:
        sys.exit(2)
    a, b, c, s, n = m.groups()
    return (int(a), int(b), int(c), 0 if s else 1, s or '', int(n or 0))
sys.exit(0 if key(sys.argv[1]) > key(sys.argv[2]) else 1)
PY
}
