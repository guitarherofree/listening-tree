#!/bin/bash
# Listening Tree update installer.
#
# Replaces an installed copy of the app with the copy inside a disk image.
# Settings and projects live outside the app bundle, so they are not touched;
# the settings are also backed up first, in case a new version changes them.
# The previous version goes to the Trash, so it can be put back if needed.
#
# Who runs this:
#   * the in-app updater, after the app quits (core/updater/installlauncher.cpp
#     starts a copy of this file from the app's update folder), and
#   * scripts/install.sh, to install a .dmg by hand.
#
# Usage:
#   install-update.sh --dmg FILE --target "/Applications/Listening Tree.app"
#                     [--wait-pid PID] [--relaunch] [--settings-file PLIST]
#                     [--app-data DIR] [--keep-dmg] [--no-dialogs]
#
# Log: ~/Library/Logs/<app name>/updates.log
#
# Written for macOS's /bin/bash (version 3.2).

set -u
umask 022

# Use the system's tools, whatever PATH the caller had. (Tests put stand-ins first
# through LT_INSTALLER_TEST_PATH; see tests/test-install-update.sh.)
PATH="${LT_INSTALLER_TEST_PATH:+$LT_INSTALLER_TEST_PATH:}/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

DMG=""
TARGET=""
WAIT_PID=""
RELAUNCH=0
SETTINGS_FILE=""
APP_DATA=""
KEEP_DMG=0
DIALOGS=1

while [ $# -gt 0 ]; do
    case "$1" in
        --dmg) DMG="$2"; shift ;;
        --target) TARGET="$2"; shift ;;
        --wait-pid) WAIT_PID="$2"; shift ;;
        --relaunch) RELAUNCH=1 ;;
        --settings-file) SETTINGS_FILE="$2"; shift ;;
        --app-data) APP_DATA="$2"; shift ;;
        --keep-dmg) KEEP_DMG=1 ;;
        --no-dialogs) DIALOGS=0 ;;
        *) echo "install-update.sh: unknown option $1" >&2; exit 2 ;;
    esac
    shift
done

TARGET="${TARGET%/}"
APP_LABEL="$(basename "$TARGET" .app)"
[ -n "$APP_LABEL" ] || APP_LABEL="Listening Tree"
LOG_DIR="$HOME/Library/Logs/$APP_LABEL"
LOG="$LOG_DIR/updates.log"
mkdir -p "$LOG_DIR" 2>/dev/null || LOG="/dev/null"

MOUNT=""
STAGE=""
OLD=""
NEW_VER=""
OLD_VER=""

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"
    if [ -t 1 ]; then printf '%s\n' "$*"; fi
}

detach_image() {
    if [ -n "$MOUNT" ]; then
        hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || hdiutil detach "$MOUNT" -quiet -force >/dev/null 2>&1 || true
        rmdir "$MOUNT" 2>/dev/null || true
        MOUNT=""
    fi
}

cleanup() {
    detach_image
    if [ -n "$STAGE" ] && [ -e "$STAGE" ]; then rm -rf "$STAGE"; fi
}
trap cleanup EXIT

alert() {
    [ "$DIALOGS" = 1 ] || return 0
    osascript - "$1" "$2" >/dev/null 2>&1 <<'OSA'
on run argv
    display alert (item 1 of argv) message (item 2 of argv) as warning buttons {"OK"} default button "OK"
end run
OSA
}

fail() {
    log "ERROR: $*"
    # If the installed version was moved aside and the new one is not in place, put it back.
    if [ -n "$OLD" ] && [ -e "$OLD" ] && [ ! -e "$TARGET" ]; then
        if mv "$OLD" "$TARGET"; then log "Put the previous version back"; fi
    fi
    detach_image
    alert "$APP_LABEL could not install the update" "$*

The version you had is still installed. The downloaded disk image is at:
$DMG

Details are in ~/Library/Logs/$APP_LABEL/updates.log"
    if [ "$RELAUNCH" = 1 ] && [ -d "$TARGET" ]; then open "$TARGET" 2>/dev/null || true; fi
    exit 1
}

plist_get() {
    plutil -extract "$2" raw -o - "$1/Contents/Info.plist" 2>/dev/null
}

can_write() {
    local dir
    dir="$(dirname "$TARGET")"
    [ -w "$dir" ] || return 1
    [ ! -e "$TARGET" ] || [ -w "$TARGET" ] || return 1
    return 0
}

backup_settings() {
    [ -n "$APP_DATA" ] || return 0
    local root="$APP_DATA/UpdateBackups"
    local dir
    dir="$root/$(date '+%Y%m%d-%H%M%S')-before-${NEW_VER:-update}"
    if ! mkdir -p "$dir"; then
        log "warning: could not create $dir; continuing without a settings backup"
        return 0
    fi

    if [ -n "$SETTINGS_FILE" ]; then
        local domain
        domain="$(basename "$SETTINGS_FILE" .plist)"
        if defaults export "$domain" "$dir/preferences.plist" >>"$LOG" 2>&1; then
            :
        elif [ -f "$SETTINGS_FILE" ]; then
            cp -p "$SETTINGS_FILE" "$dir/preferences.plist" || log "warning: could not copy $SETTINGS_FILE"
        fi
    fi

    if [ -d "$APP_DATA" ]; then
        local total backups
        total="$(du -sk "$APP_DATA" 2>/dev/null | cut -f1)"
        backups="$(du -sk "$root" 2>/dev/null | cut -f1)"
        if [ $(( ${total:-0} - ${backups:-0} )) -gt 512000 ]; then
            log "note: $APP_DATA is larger than 500 MB; only the preferences were backed up"
        elif ! (cd "$APP_DATA" && tar -czf "$dir/app-data.tar.gz" \
                    --exclude ./UpdateBackups --exclude ./update --exclude ./logs . ) >>"$LOG" 2>&1; then
            log "warning: could not archive $APP_DATA"
        fi
    fi

    # Keep the five newest backups.
    local count
    count="$(ls -1 "$root" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${count:-0}" -gt 5 ]; then
        ls -1 "$root" | sort | head -n $((count - 5)) | while read -r old; do
            [ -n "$old" ] && rm -rf "${root:?}/$old"
        done
    fi
    log "Settings backed up to $dir"
}

swap_in() {
    local dir name
    dir="$(dirname "$TARGET")"
    name="$(basename "$TARGET")"
    STAGE="$dir/.$name.new-$$"
    OLD="$dir/.$name.old-$$"

    if can_write; then
        ditto "$NEW_APP" "$STAGE" >>"$LOG" 2>&1 || fail "Could not copy the new version into $(dirname "$TARGET")."
        xattr -dr com.apple.quarantine "$STAGE" >/dev/null 2>&1 || true
        if [ -e "$TARGET" ]; then
            mv "$TARGET" "$OLD" || fail "Could not move the current version aside."
        fi
        if ! mv "$STAGE" "$TARGET"; then
            fail "Could not put the new version in place."
        fi
        STAGE=""
        if [ -e "$OLD" ]; then
            local trash="$HOME/.Trash/$APP_LABEL ${OLD_VER:-previous}.app"
            [ -e "$trash" ] && trash="$HOME/.Trash/$APP_LABEL ${OLD_VER:-previous} $(date '+%H%M%S').app"
            if mv "$OLD" "$trash" 2>/dev/null; then
                log "Moved the previous version to the Trash: $trash"
            else
                rm -rf "$OLD"
            fi
        fi
        OLD=""
    else
        # The app's folder needs an administrator (for example an app installed by another user).
        log "Asking for an administrator password to write to $(dirname "$TARGET")"
        local helper
        helper="$(mktemp "${TMPDIR:-/tmp}/lt-swap.XXXXXX")" || fail "Could not create a temporary file."
        cat > "$helper" <<'SWAP'
set -e
new_app="$1"; target="$2"; stage="$3"; old="$4"
ditto "$new_app" "$stage"
xattr -dr com.apple.quarantine "$stage" 2>/dev/null || true
if [ -e "$target" ]; then mv "$target" "$old"; fi
if ! mv "$stage" "$target"; then
    if [ -e "$old" ]; then mv "$old" "$target"; fi
    rm -rf "$stage"
    exit 1
fi
rm -rf "$old"
SWAP
        if ! osascript - "$helper" "$NEW_APP" "$TARGET" "$STAGE" "$OLD" >>"$LOG" 2>&1 <<'OSA'
on run argv
    set cmd to "/bin/bash " & quoted form of (item 1 of argv)
    repeat with i from 2 to count of argv
        set cmd to cmd & " " & quoted form of (item i of argv)
    end repeat
    do shell script cmd with administrator privileges
end run
OSA
        then
            rm -f "$helper"
            STAGE=""
            OLD=""
            fail "The update needs an administrator password to replace $TARGET."
        fi
        rm -f "$helper"
        STAGE=""
        OLD=""
    fi
}

# --- main -----------------------------------------------------------------------

[ -n "$TARGET" ] || fail "No --target app given."
case "$TARGET" in
    *.app) ;;
    *) fail "The target is not an app bundle: $TARGET" ;;
esac
case "$TARGET" in
    */AppTranslocation/*)
        fail "macOS is running $APP_LABEL from a temporary, read-only location because it was opened straight from Downloads. Drag $APP_LABEL into your Applications folder, open it from there, and update again." ;;
esac
[ -f "$DMG" ] || fail "The downloaded update was not found: $DMG"

log "=== Installing $(basename "$DMG") into $TARGET"

# 1. Wait for the app to quit (all of its windows, which can be separate processes).
if [ -n "$WAIT_PID" ]; then
    n=0
    while kill -0 "$WAIT_PID" 2>/dev/null; do
        n=$((n + 1))
        [ $n -ge 600 ] && fail "$APP_LABEL did not quit within 5 minutes."
        sleep 0.5
    done
fi
n=0
while pgrep -f "$TARGET/Contents/MacOS/" >/dev/null 2>&1; do
    n=$((n + 1))
    [ $n -ge 120 ] && fail "$APP_LABEL is still running. Quit it and try again."
    sleep 0.5
done

# 2. Open the disk image and find the app in it.
MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/lt-update.XXXXXX")" || fail "Could not create a temporary folder."
hdiutil attach "$DMG" -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" -quiet >>"$LOG" 2>&1 \
    || { rmdir "$MOUNT" 2>/dev/null; MOUNT=""; fail "Could not open the disk image; it may be damaged. Try downloading the update again."; }

NEW_APP=""
for candidate in "$MOUNT"/*.app; do
    if [ -d "$candidate" ]; then NEW_APP="$candidate"; break; fi
done
[ -n "$NEW_APP" ] || fail "The disk image does not contain an app."

NEW_ID="$(plist_get "$NEW_APP" CFBundleIdentifier)"
NEW_VER="$(plist_get "$NEW_APP" CFBundleShortVersionString)"
if [ -d "$TARGET" ]; then
    OLD_ID="$(plist_get "$TARGET" CFBundleIdentifier)"
    OLD_VER="$(plist_get "$TARGET" CFBundleShortVersionString)"
    if [ -n "$OLD_ID" ] && [ "$NEW_ID" != "$OLD_ID" ]; then
        fail "The disk image holds a different app ($NEW_ID) than the one installed ($OLD_ID)."
    fi
fi
log "New version ${NEW_VER:-?} ($NEW_ID); installed version ${OLD_VER:-none}"

# 3. Check that the new app is intact.
if ! codesign --verify --deep --strict "$NEW_APP" >>"$LOG" 2>&1; then
    fail "The app in the update failed its code-signature check, so it may be damaged. Try downloading the update again."
fi

# 4. Back up settings, then 5. replace the app.
backup_settings
swap_in

if [ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$TARGET" >/dev/null 2>&1 || true
fi
log "Installed $APP_LABEL ${NEW_VER:-} at $TARGET"

detach_image
if [ "$KEEP_DMG" = 0 ]; then rm -f "$DMG"; fi

if [ "$RELAUNCH" = 1 ]; then
    open "$TARGET" || log "warning: could not reopen $TARGET"
fi
exit 0
