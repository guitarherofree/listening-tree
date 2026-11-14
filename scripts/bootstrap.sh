#!/usr/bin/env bash
# Installs what building Listening Tree needs, into .tools/ in this repository.
#
#   scripts/bootstrap.sh            check Xcode, install CMake/Ninja/aqtinstall and Qt
#   scripts/bootstrap.sh --with-gh  also install the GitHub CLI (needed to publish releases)
#
# Nothing is installed system-wide except what you approve yourself (Xcode's
# command-line tools). Delete .tools/ to start over. Run it again any time;
# it skips what is already there.

. "$(dirname "$0")/lib/common.sh"

WITH_GH=0
for arg in "$@"; do
    case "$arg" in
        --with-gh) WITH_GH=1 ;;
        -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $arg" ;;
    esac
done

is_macos || die "Listening Tree builds on macOS only. (On Linux you can still work on patches: scripts/prepare-source.sh)"

# --- Xcode -------------------------------------------------------------------------
info "Checking Xcode"
if ! xcode-select -p >/dev/null 2>&1; then
    die "Xcode's command-line tools are missing. Install them with:  xcode-select --install
       (or install Xcode from the App Store), then run this script again."
fi
xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1 || die "The macOS SDK was not found. Open Xcode once, or run: xcode-select --install"
ok "Xcode tools: $(xcode-select -p)"
actool_version="$(xcrun actool --version 2>/dev/null | tr -d '\n\t ' | sed -n 's/.*<key>short-bundle-version<\/key><string>\([^<]*\)<\/string>.*/\1/p')"
case "$actool_version" in
    2[6-9]*|[3-9][0-9]*) ok "Xcode $actool_version can build the app icon" ;;
    *) warn "Xcode 26 or newer is not selected, so builds use the prebuilt app icon (fine for everyday work)." ;;
esac

# --- Python tools: CMake, Ninja, aqtinstall -----------------------------------------
PY="$(command -v python3 || true)"
[ -n "$PY" ] || die "python3 not found (it comes with Xcode's command-line tools)"
if [ ! -x "$TOOLS_DIR/venv/bin/python" ]; then
    info "Creating a Python environment in .tools/venv"
    "$PY" -m venv "$TOOLS_DIR/venv"
fi
info "Installing CMake, Ninja and aqtinstall"
"$TOOLS_DIR/venv/bin/python" -m pip install --quiet --upgrade pip
"$TOOLS_DIR/venv/bin/python" -m pip install --quiet --upgrade "cmake>=3.28,<5" "ninja>=1.11" "aqtinstall>=3.3,<4"
use_tools
ok "cmake $(cmake --version | head -1 | awk '{print $3}'), ninja $(ninja --version)"

# --- Qt -------------------------------------------------------------------------------
if [ -x "$QT_DIR/bin/qmake" ] || [ -x "$QT_DIR/bin/qtpaths" ]; then
    ok "Qt $QT_VERSION already installed in ${QT_DIR#"$LT_ROOT"/}"
else
    info "Downloading Qt $QT_VERSION (about 1.5 GB, takes a while)"
    # shellcheck disable=SC2086  # QT_MODULES is a space-separated list
    aqt install-qt mac desktop "$QT_VERSION" clang_64 -m $QT_MODULES --outputdir "$TOOLS_DIR/Qt"
    [ -d "$QT_DIR" ] || die "Qt was not installed where expected ($QT_DIR)"
    ok "Qt $QT_VERSION installed"
fi

# --- Optional: ccache, GitHub CLI ----------------------------------------------------
if command -v ccache >/dev/null 2>&1; then
    ok "ccache found: rebuilds after switching branches will be faster"
elif command -v brew >/dev/null 2>&1; then
    warn "Optional: 'brew install ccache' makes repeated full builds much faster."
fi

if [ "$WITH_GH" = 1 ]; then
    if command -v gh >/dev/null 2>&1; then
        ok "GitHub CLI found: $(gh --version | head -1)"
    elif command -v brew >/dev/null 2>&1; then
        info "Installing the GitHub CLI with Homebrew"
        brew install gh
    else
        info "Downloading the GitHub CLI"
        arch="$(host_arch)"; [ "$arch" = x86_64 ] && arch=amd64
        url="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
               | "$PY" -c 'import json,sys; a=sys.argv[1]; urls=[x["browser_download_url"] for x in json.load(sys.stdin)["assets"]]; m=[u for u in urls if u.endswith("_macOS_%s.zip" % a)] or [u for u in urls if u.endswith("_macOS_universal.zip")]; print(m[0] if m else "")' "$arch")"
        [ -n "$url" ] || die "Could not find a GitHub CLI download. Install it from https://cli.github.com instead."
        tmp="$(mktemp -d)"
        curl -fsSL -o "$tmp/gh.zip" "$url"
        ditto -x -k "$tmp/gh.zip" "$tmp/x"
        mkdir -p "$TOOLS_DIR/bin"
        cp "$(find "$tmp/x" -type f -name gh -perm -u+x | head -1)" "$TOOLS_DIR/bin/gh"
        rm -rf "$tmp"
        use_tools
    fi
    if ! gh auth status >/dev/null 2>&1; then
        warn "Sign the GitHub CLI in to your account once with:  \"$(command -v gh)\" auth login"
    fi
fi

ok "Ready. Next: scripts/build.sh   (first build takes 30-60 minutes)"
