#!/usr/bin/env bash
# Stores (or removes) the GitHub token the in-app updater uses while the
# repository is private. The token lives in your login Keychain.
#
#   scripts/set-update-token.sh            store a token (you are asked to paste it)
#   scripts/set-update-token.sh --remove   delete it (e.g. after making the repository public)
#   scripts/set-update-token.sh --check    test the stored token against GitHub
#
# Create the token at https://github.com/settings/personal-access-tokens/new :
#   Repository access: only this repository; Permissions: Contents = Read-only.
# See docs/UPDATING.md.

. "$(dirname "$0")/lib/common.sh"
is_macos || die "The Keychain is macOS-only."

SERVICE="$UPDATE_TOKEN_KEYCHAIN_SERVICE"
ACCOUNT="$UPDATE_TOKEN_KEYCHAIN_ACCOUNT"

check() {
    local token code
    token="$(security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w 2>/dev/null)" || die "No token stored."
    code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $token" \
            -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$GITHUB_REPO/releases?per_page=1")"
    case "$code" in
        200) ok "The token can read releases of $GITHUB_REPO" ;;
        401) die "GitHub rejected the token (expired or mistyped). Store a new one." ;;
        403|404) die "The token cannot see $GITHUB_REPO. Give it access to that repository with Contents: Read-only." ;;
        *) die "Unexpected answer from GitHub (HTTP $code)" ;;
    esac
}

case "${1:-}" in
    --remove)
        security delete-generic-password -s "$SERVICE" -a "$ACCOUNT" >/dev/null 2>&1 && ok "Token removed" || warn "No token was stored"
        ;;
    --check)
        check
        ;;
    "")
        printf 'Paste the GitHub token (input is hidden), then press Return: '
        IFS= read -rs token; echo
        [ -n "$token" ] || die "No token entered"
        # -T /usr/bin/security lets the updater read it via the security tool without a prompt.
        security add-generic-password -U -s "$SERVICE" -a "$ACCOUNT" -l "$APP_NAME updates (GitHub token)" \
            -T /usr/bin/security -w "$token"
        unset token
        ok "Token stored in your login Keychain as \"$APP_NAME updates (GitHub token)\""
        check
        ;;
    *) die "unknown option: $1" ;;
esac
