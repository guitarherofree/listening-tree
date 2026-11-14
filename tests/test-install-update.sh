#!/usr/bin/env bash
# Exercises packaging/macos/install-update.sh with stand-ins for the macOS tools
# (hdiutil, codesign, ditto, plutil, ...), so it runs on Linux as well as macOS.
#
#   tests/test-install-update.sh
#
# A "disk image" here is a tar file; the hdiutil stand-in unpacks it.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$ROOT/packaging/macos/install-update.sh"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
STUBS="$T/stubs"; mkdir -p "$STUBS"
export STUB_LOG="$T/stub.log"

stub() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$STUBS/$1"; chmod +x "$STUBS/$1"; }
stub hdiutil 'case "$1" in
  attach) dmg="$2"; mp=""; while [ $# -gt 0 ]; do [ "$1" = -mountpoint ] && mp="$2"; shift; done
          tar -xf "$dmg" -C "$mp" ;;
  detach) find "$2" -mindepth 1 -delete 2>/dev/null || true ;;
esac'
stub codesign 'exit "${STUB_CODESIGN_EXIT:-0}"'
stub ditto 'cp -R "$1" "$2"'
stub xattr 'exit 0'
stub defaults 'exit 1'
stub pgrep 'exit 1'
stub open 'echo "open $*" >> "$STUB_LOG"'
stub osascript 'script="$(cat)"
if printf "%s" "$script" | grep -q "administrator privileges"; then shift; helper="$1"; shift; exec bash "$helper" "$@"; fi
echo "alert $*" >> "$STUB_LOG"'
stub plutil 'key="$2"; file="${!#}"; python3 -c "import plistlib,sys; print(plistlib.load(open(sys.argv[1],\"rb\"))[sys.argv[2]])" "$file" "$key"'
export LT_INSTALLER_TEST_PATH="$STUBS"

make_app() { # dir id version
    mkdir -p "$1/Contents/MacOS"
    echo "binary $3" > "$1/Contents/MacOS/audacity"
    python3 - "$1/Contents/Info.plist" "$2" "$3" <<'PY'
import plistlib, sys
plistlib.dump({"CFBundleIdentifier": sys.argv[2], "CFBundleShortVersionString": sys.argv[3]}, open(sys.argv[1], "wb"))
PY
}
make_dmg() { # dmg id version
    local d; d="$(mktemp -d)"; make_app "$d/Listening Tree.app" "$2" "$3"
    tar -cf "$1" -C "$d" .; rm -rf "$d"
}

pass=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "  ok   $1"; else echo "  FAIL $1"; echo "--- log"; cat "$HOME/Library/Logs/Listening Tree/updates.log" 2>/dev/null; exit 1; fi; }

setup() {
    export HOME="$T/home-$1"; mkdir -p "$HOME/.Trash" "$HOME/Apps"
    APP="$HOME/Apps/Listening Tree.app"; make_app "$APP" com.example.lt 0.1.0
    DATA="$HOME/Library/Application Support/ListeningTree/ListeningTree"; mkdir -p "$DATA/workspaces" "$DATA/update"
    echo "workspace" > "$DATA/workspaces/default.json"; echo "big" > "$DATA/update/old.dmg"
    PREFS="$HOME/Library/Preferences/com.example.ListeningTree.plist"; mkdir -p "$(dirname "$PREFS")"; echo "prefs" > "$PREFS"
    : > "$STUB_LOG"
}
run() { bash "$INSTALLER" --target "$APP" --settings-file "$PREFS" --app-data "$DATA" "$@"; }

echo "update replaces the app and keeps settings"
setup a; make_dmg "$T/a.dmg" com.example.lt 0.2.0
sleep 1 & waiter=$!
run --dmg "$T/a.dmg" --wait-pid "$waiter" --relaunch
check "new version installed" '[ "$(cat "$APP/Contents/MacOS/audacity")" = "binary 0.2.0" ]'
check "previous version in the Trash" '[ -d "$HOME/.Trash/Listening Tree 0.1.0.app" ]'
check "settings untouched" '[ "$(cat "$PREFS")" = prefs ] && [ -f "$DATA/workspaces/default.json" ]'
check "settings backed up" 'ls "$DATA"/UpdateBackups/*-before-0.2.0/preferences.plist >/dev/null && tar -tzf "$DATA"/UpdateBackups/*-before-0.2.0/app-data.tar.gz | grep -q workspaces/default.json'
check "update folder not in backup" '! tar -tzf "$DATA"/UpdateBackups/*-before-0.2.0/app-data.tar.gz | grep -q old.dmg'
check "disk image removed" '[ ! -e "$T/a.dmg" ]'
check "app reopened" 'grep -q "open $APP" "$STUB_LOG"'
check "no leftovers next to the app" '[ -z "$(ls -A "$HOME/Apps" | grep -v "^Listening Tree.app$")" ]'

echo "a disk image for another app is refused"
setup b; make_dmg "$T/b.dmg" com.example.other 9.9.9
if run --dmg "$T/b.dmg" --relaunch; then exit 1; fi
check "installed app unchanged" '[ "$(cat "$APP/Contents/MacOS/audacity")" = "binary 0.1.0" ]'
check "user told" 'grep -q "^alert" "$STUB_LOG"'
check "old app reopened" 'grep -q "open $APP" "$STUB_LOG"'
check "disk image kept for manual install" '[ -f "$T/b.dmg" ]'

echo "a damaged app is refused"
setup c; make_dmg "$T/c.dmg" com.example.lt 0.2.0
if STUB_CODESIGN_EXIT=1 run --dmg "$T/c.dmg" --no-dialogs; then exit 1; fi
check "installed app unchanged" '[ "$(cat "$APP/Contents/MacOS/audacity")" = "binary 0.1.0" ]'
check "no dialog with --no-dialogs" '! grep -q "^alert" "$STUB_LOG"'

echo "translocated apps are refused"
setup d; make_dmg "$T/d.dmg" com.example.lt 0.2.0
if bash "$INSTALLER" --target "/private/var/folders/x/AppTranslocation/ABC/d/Listening Tree.app" --dmg "$T/d.dmg" --no-dialogs; then exit 1; fi
check "refused" 'grep -q "temporary, read-only location" "$HOME/Library/Logs/Listening Tree/updates.log"'

echo "first install (nothing installed yet)"
setup e; rm -rf "$APP"; make_dmg "$T/e.dmg" com.example.lt 0.2.0
run --dmg "$T/e.dmg" --keep-dmg --no-dialogs
check "installed" '[ "$(cat "$APP/Contents/MacOS/audacity")" = "binary 0.2.0" ]'
check "disk image kept with --keep-dmg" '[ -f "$T/e.dmg" ]'

echo "backups are pruned to the newest five"
setup f
for i in 1 2 3 4 5 6 7; do mkdir -p "$DATA/UpdateBackups/2026010$i-000000-before-0.0.$i"; done
make_dmg "$T/f.dmg" com.example.lt 0.2.0
run --dmg "$T/f.dmg" --no-dialogs
check "five kept" '[ "$(ls "$DATA/UpdateBackups" | wc -l | tr -d " ")" = 5 ]'
check "newest kept" 'ls "$DATA/UpdateBackups" | grep -q before-0.2.0'

echo "$pass checks passed"
