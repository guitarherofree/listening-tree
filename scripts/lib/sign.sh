# shellcheck shell=bash
# Code signing for the app bundle. Source this file; don't run it.
#
# Without an Apple Developer ID, builds are signed "ad hoc" (identity "-"),
# which is what Apple Silicon needs to run them. To sign with a certificate in
# your Keychain instead, set LT_CODESIGN_IDENTITY, for example
#   export LT_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"

# sign_app <app> <entitlements.plist> [hardened]
sign_app() {
    local app="$1" entitlements="$2" hardened="${3:-}"
    local identity="${LT_CODESIGN_IDENTITY:--}"
    local opts=(--force --sign "$identity")
    if [ -n "$hardened" ]; then opts+=(--options runtime); fi
    if [ "$identity" != "-" ]; then opts+=(--timestamp); fi

    info "Signing $(basename "$app") (identity: ${identity/#-/ad hoc})"
    # codesign --deep does not look inside Contents/Resources, so sign libraries there first
    # (the same as upstream's make_dmg.sh).
    find "$app/Contents/Resources" -type f \( -name '*.dylib' -o -name '*.so' \) -print0 \
        | xargs -0 -n 25 -P 4 codesign "${opts[@]}" >/dev/null 2>&1 || true
    codesign "${opts[@]}" --deep --entitlements "$entitlements" "$app"
    codesign --verify --deep --strict "$app"
}
