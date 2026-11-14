#!/usr/bin/env bash
# Builds Listening Tree on macOS.
#
#   scripts/build.sh               development build (fast to rebuild; own settings, "ListeningTreeDev")
#   scripts/build.sh --release     release build, the kind that gets packaged and published
#
# Options:
#   --arch arm64|x86_64|universal  CPU type to build for (default: this Mac's)
#   --clean                        delete the build folder first (a full rebuild)
#   --skip-prepare                 don't sync work/audacity with patches/ first
#   --jobs N                       parallel compile jobs (default: all cores)
#
# Output: work/install-<dev|release>-<arch>/audacity.app
# Run a development build with scripts/run.sh; package a release with scripts/package.sh.

. "$(dirname "$0")/lib/common.sh"
. "$(dirname "$0")/lib/sign.sh"

MODE=dev
ARCH="$(host_arch)"
CLEAN=0
PREPARE=1
JOBS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --release) MODE=release ;;
        --dev) MODE=dev ;;
        --arch) ARCH="$2"; shift ;;
        --clean) CLEAN=1 ;;
        --skip-prepare) PREPARE=0 ;;
        --jobs) JOBS="$2"; shift ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

case "$ARCH" in
    arm64|x86_64) OSX_ARCHS="$ARCH" ;;
    universal) OSX_ARCHS="arm64;x86_64" ;;
    *) die "--arch must be arm64, x86_64 or universal" ;;
esac

is_macos || die "Building the app needs macOS. (On Linux you can still work on patches: scripts/prepare-source.sh)"
use_tools
require_cmd cmake
require_cmd ninja
[ -d "$QT_DIR" ] || die "Qt $QT_VERSION not found in ${QT_DIR}. Run scripts/bootstrap.sh first."

if [ "$PREPARE" = 1 ]; then
    "$LT_ROOT/scripts/prepare-source.sh" --quiet
fi

BUILD_DIR="$WORK_DIR/build-$MODE-$ARCH"
INSTALL_DIR="$WORK_DIR/install-$MODE-$ARCH"
APP="$INSTALL_DIR/$BUILT_APP_NAME"
[ "$CLEAN" = 1 ] && rm -rf "$BUILD_DIR"

export MACOSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET"
if command -v ccache >/dev/null 2>&1; then
    export CCACHE_SLOPPINESS="pch_defines,time_macros,include_file_mtime,include_file_ctime"
    export CCACHE_BASEDIR="$LT_ROOT"
fi

info "Configuring ($MODE, $ARCH)"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_PREFIX_PATH="$QT_DIR" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" \
    -DCMAKE_OSX_ARCHITECTURES="$OSX_ARCHS" \
    -DLT_ROOT="$LT_ROOT" \
    -DAU4_BUILD_MODE="$MODE" \
    -DAU4_BUILD_CONFIGURATION=app \
    -DMUSE_ENABLE_UNIT_TESTS=OFF \
    -DAU_BUILD_USAGEINFO_MODULE=OFF \
    >"$WORK_DIR/configure-$MODE-$ARCH.log" 2>&1 \
    || { tail -40 "$WORK_DIR/configure-$MODE-$ARCH.log"; die "Configuring failed; full log: work/configure-$MODE-$ARCH.log"; }

info "Compiling (the first build takes a while; later builds only redo what changed)"
if [ -n "$JOBS" ]; then
    cmake --build "$BUILD_DIR" -- -j "$JOBS"
else
    cmake --build "$BUILD_DIR"
fi

info "Assembling the app bundle"
rm -rf "$INSTALL_DIR"
cmake --install "$BUILD_DIR" >"$WORK_DIR/install-$MODE-$ARCH.log" 2>&1 \
    || { tail -40 "$WORK_DIR/install-$MODE-$ARCH.log"; die "Install step failed; full log: work/install-$MODE-$ARCH.log"; }
[ -d "$APP" ] || die "Expected $APP after installing"

# The update helper travels inside the app, so every build can install updates.
mkdir -p "$APP/Contents/Resources/listening-tree"
cp "$LT_ROOT/packaging/macos/install-update.sh" "$APP/Contents/Resources/listening-tree/install-update.sh"
chmod 755 "$APP/Contents/Resources/listening-tree/install-update.sh"

ENTITLEMENTS="$SRC_DIR/buildscripts/packaging/MacOS/macosx_entitlements.plist"
if [ "$MODE" = release ]; then
    sign_app "$APP" "$ENTITLEMENTS" hardened
else
    sign_app "$APP" "$ENTITLEMENTS"
fi

version="$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist" 2>/dev/null || echo "?")"
ok "Built $APP_NAME $version ($MODE, $ARCH): ${APP#"$LT_ROOT"/}"
if [ "$MODE" = dev ]; then
    echo "   Run it with:  scripts/run.sh"
else
    echo "   Package it with:  scripts/package.sh${ARCH:+ --arch $ARCH}"
fi
