#!/usr/bin/env bash
# Prepares work/audacity: the pinned Audacity release (config/upstream.env)
# with Listening Tree's branding overlay and patches applied as git commits.
#
#   scripts/prepare-source.sh            create it, or bring it up to date with patches/
#   scripts/prepare-source.sh --reset    rebuild it from scratch (re-applies every patch)
#   scripts/prepare-source.sh --force    like --reset, discarding unsaved edits in work/audacity
#
# work/audacity is a normal git repository. Branch "listening-tree" holds one
# commit per patch on top of tag "lt-base" (= upstream + branding overlay).
# Edit and commit there, then run scripts/save-patches.sh. See docs/DEVELOPING.md.

. "$(dirname "$0")/lib/common.sh"

RESET=0
FORCE=0
QUIET=0
FRESH=0
for arg in "$@"; do
    case "$arg" in
        --reset) RESET=1 ;;
        --force) RESET=1; FORCE=1 ;;
        --quiet) QUIET=1 ;;
        -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $arg" ;;
    esac
done

STAMP="$WORK_DIR/.prepared"
WANT="$(patches_fingerprint)"

stamp_get() { [ -f "$STAMP" ] && sed -n "s/^$1=//p" "$STAMP" | head -1 || true; }

write_stamp() {
    mkdir -p "$WORK_DIR"
    {
        echo "fingerprint=$(patches_fingerprint)"
        echo "audacity_head=$(wgit rev-parse HEAD)"
        echo "muse_head=$(mgit rev-parse HEAD)"
    } > "$STAMP"
}

# True when work/audacity has edits or commits that are not yet in patches/.
has_unsaved_work() {
    [ -d "$SRC_DIR/.git" ] || return 1
    # No stamp means preparation never finished (e.g. it was interrupted): nothing to protect.
    [ -f "$STAMP" ] || return 1
    if [ -n "$(wgit status --porcelain --ignore-submodules=all 2>/dev/null)" ]; then return 0; fi
    if [ -d "$SRC_DIR/muse/.git" ] || [ -f "$SRC_DIR/muse/.git" ]; then
        if [ -n "$(mgit status --porcelain 2>/dev/null)" ]; then return 0; fi
        if [ "$(mgit rev-parse HEAD 2>/dev/null)" != "$(stamp_get muse_head)" ]; then return 0; fi
    fi
    if [ "$(wgit rev-parse HEAD 2>/dev/null)" != "$(stamp_get audacity_head)" ]; then return 0; fi
    return 1
}

refuse_if_unsaved() {
    if [ "$FORCE" = 0 ] && has_unsaved_work; then
        die "work/audacity has changes that are not saved in patches/.
       Save them first:   scripts/save-patches.sh
       or discard them:   scripts/prepare-source.sh --force"
    fi
}

fresh_clone() {
    refuse_if_unsaved
    rm -rf "$SRC_DIR" "$STAMP"
    mkdir -p "$WORK_DIR"
    info "Downloading Audacity $AUDACITY_TAG"
    git "${GIT_WORK_FLAGS[@]}" clone --quiet --depth 1 --branch "$AUDACITY_TAG" "$AUDACITY_GIT_URL" "$SRC_DIR"
    local actual
    actual="$(wgit rev-parse HEAD)"
    [ "$actual" = "$AUDACITY_COMMIT" ] || die "$AUDACITY_TAG is commit $actual, but config/upstream.env pins $AUDACITY_COMMIT.
       If upstream re-tagged on purpose, update AUDACITY_COMMIT."
    info "Downloading the MuseScore framework submodules"
    wgit submodule update --quiet --init --depth 1 muse muse_deps
    wgit tag -f lt-upstream >/dev/null
    mgit tag -f lt-upstream >/dev/null
    FRESH=1
}

reset_to_upstream() {
    [ "$FRESH" = 1 ] || refuse_if_unsaved
    if [ -d "$SRC_DIR/.git/rebase-apply" ]; then wgit am --abort || true; fi
    if [ -d "$SRC_DIR/.git/modules/muse/rebase-apply" ]; then mgit am --abort || true; fi
    mgit checkout --quiet -B listening-tree lt-upstream
    mgit reset --quiet --hard lt-upstream
    mgit clean --quiet -fdx
    wgit checkout --quiet -B listening-tree lt-upstream
    wgit reset --quiet --hard lt-upstream
    wgit clean --quiet -fdx -e muse -e muse_deps
    wgit submodule update --quiet --init --depth 1 muse_deps
    git -C "$SRC_DIR/muse_deps" reset --quiet --hard
    git -C "$SRC_DIR/muse_deps" clean --quiet -fdx
}

apply_overlay() {
    local overlay="$LT_ROOT/branding/overlay"
    if [ -d "$overlay" ]; then
        info "Applying branding overlay"
        (cd "$overlay" && tar cf - .) | (cd "$SRC_DIR" && tar xf -)
        wgit add -A -- . ':(exclude)muse' ':(exclude)muse_deps'
        if ! wgit diff --cached --quiet; then
            wgit commit --quiet -m "Listening Tree branding overlay (generated from branding/overlay)"
        fi
    fi
    wgit tag -f lt-base >/dev/null
    mgit tag -f lt-base >/dev/null
}

apply_patches() {
    local dir="$1" label="$2"; shift 2
    local patches
    patches="$(find "$dir" -maxdepth 1 -name '*.patch' 2>/dev/null | LC_ALL=C sort)"
    [ -n "$patches" ] || return 0
    info "Applying $(printf '%s\n' "$patches" | wc -l | tr -d ' ') $label patch(es)"
    # shellcheck disable=SC2086
    if ! "$@" am --quiet --3way --keep-non-patch $patches; then
        die "A $label patch did not apply (see the message above).
       Fix it inside work/audacity${label/audacity/}, then run:
         git -C work/audacity${label/audacity/} am --continue
         scripts/save-patches.sh
       See \"When a patch does not apply\" in docs/DEVELOPING.md."
    fi
}

# --- main -----------------------------------------------------------------------
if [ ! -d "$SRC_DIR/.git" ] || [ "$(wgit rev-parse -q --verify lt-upstream 2>/dev/null)" != "$AUDACITY_COMMIT" ]; then
    fresh_clone
    RESET=1
elif [ "$RESET" = 0 ] && [ "$(stamp_get fingerprint)" = "$WANT" ]; then
    [ "$QUIET" = 1 ] || ok "work/audacity is up to date ($AUDACITY_TAG + $(wgit rev-list --count lt-base..HEAD) patches)"
    exit 0
fi

reset_to_upstream
apply_overlay
apply_patches "$LT_ROOT/patches/audacity" "audacity" wgit
apply_patches "$LT_ROOT/patches/muse" "audacity/muse" mgit
write_stamp
ok "work/audacity is ready: $AUDACITY_TAG + branding + $(wgit rev-list --count lt-base..HEAD) audacity and $(mgit rev-list --count lt-base..HEAD) muse patches"
