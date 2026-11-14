#!/usr/bin/env bash
# Installs Listening Tree into /Applications from a disk image, the same way the
# in-app updater does (settings are backed up, the old version goes to the Trash).
#
#   scripts/install.sh                         the newest package in dist/ (from scripts/package.sh)
#   scripts/install.sh path/to/file.dmg        a specific disk image
#   scripts/install.sh --latest                download the newest GitHub release and install it
#   scripts/install.sh --version 0.2.0         download that release and install it (also for going back)
#
# Options:
#   --to "/path/Listening Tree.app"   install somewhere else
#   --no-open                         don't open the app afterwards

. "$(dirname "$0")/lib/common.sh"
is_macos || die "Installing needs macOS."
use_tools

TARGET="/Applications/$APP_BUNDLE_NAME"
OPEN=1
SOURCE=""
DOWNLOAD_TAG=""
while [ $# -gt 0 ]; do
    case "$1" in
        --latest) DOWNLOAD_TAG="latest" ;;
        --version) DOWNLOAD_TAG="v${2#v}"; shift ;;
        --to) TARGET="$2"; shift ;;
        --no-open) OPEN=0 ;;
        -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option: $1" ;;
        *) SOURCE="$1" ;;
    esac
    shift
done

ARCH="$(host_arch)"
if [ -n "$DOWNLOAD_TAG" ]; then
    require_cmd gh "Install the GitHub CLI: scripts/bootstrap.sh --with-gh"
    dl="$DIST_DIR/downloads"
    mkdir -p "$dl"
    tag_arg=()
    [ "$DOWNLOAD_TAG" != latest ] && tag_arg=("$DOWNLOAD_TAG")
    info "Downloading ${DOWNLOAD_TAG/#latest/the latest release} from $GITHUB_REPO"
    rm -f "$dl"/*.dmg
    gh release download ${tag_arg[@]+"${tag_arg[@]}"} --repo "$GITHUB_REPO" --dir "$dl" --pattern "*-$ARCH.dmg" --clobber 2>/dev/null \
        || gh release download ${tag_arg[@]+"${tag_arg[@]}"} --repo "$GITHUB_REPO" --dir "$dl" --pattern "*-universal.dmg" --clobber \
        || die "Could not download a disk image for $ARCH Macs"
    SOURCE="$(ls -t "$dl"/*.dmg | head -1)"
elif [ -z "$SOURCE" ]; then
    SOURCE="$(ls -t "$DIST_DIR"/*.dmg 2>/dev/null | head -1 || true)"
    [ -n "$SOURCE" ] || die "No disk image in dist/. Build one (scripts/build.sh --release && scripts/package.sh), or use --latest."
fi
[ -f "$SOURCE" ] || die "Not found: $SOURCE"

# Ask a running copy to quit (it will ask to save open projects); the installer waits for it.
if pgrep -f "$TARGET/Contents/MacOS/" >/dev/null 2>&1; then
    info "Asking $APP_NAME to quit"
    osascript -e "tell application id \"$APP_BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
fi

# Where release builds keep settings (Qt's naming on macOS; see config/app.env).
domain_reversed="$(printf '%s' "$APP_ORG_DOMAIN" | awk -F. '{ for (i = NF; i > 0; i--) printf "%s%s", $i, (i > 1 ? "." : "") }')"
SETTINGS_FILE="$HOME/Library/Preferences/$domain_reversed.$APP_SETTINGS_NAME.plist"
APP_DATA="$HOME/Library/Application Support/$APP_ORG_NAME/$APP_SETTINGS_NAME"

args=(--dmg "$SOURCE" --target "$TARGET" --keep-dmg --settings-file "$SETTINGS_FILE" --app-data "$APP_DATA")
[ "$OPEN" = 1 ] && args+=(--relaunch)
info "Installing $(basename "$SOURCE") to $TARGET"
if bash "$LT_ROOT/packaging/macos/install-update.sh" "${args[@]}"; then
    ok "Installed. (Log: ~/Library/Logs/$APP_NAME/updates.log)"
else
    die "Installation failed; see ~/Library/Logs/$APP_NAME/updates.log"
fi
