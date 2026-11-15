#!/usr/bin/env bash
# Saves your commits in work/audacity as patch files in patches/.
#
#   scripts/save-patches.sh
#
# Every commit on branch "listening-tree" after tag "lt-base" becomes one file
# in patches/audacity/ (and commits in work/audacity/muse go to patches/muse/).
# The folders are rewritten from scratch, so reordering, squashing or dropping
# commits there (git rebase -i lt-base) is reflected here too.
# Afterwards, review `git status` / `git diff` in this repository and commit.

. "$(dirname "$0")/lib/common.sh"

[ -d "$SRC_DIR/.git" ] || die "work/audacity does not exist. Run scripts/prepare-source.sh first."

if [ -n "$(wgit status --porcelain --ignore-submodules=all)" ] || [ -n "$(mgit status --porcelain)" ]; then
    wgit status --short --ignore-submodules=all
    mgit status --short | sed 's|^|muse/|'
    die "Commit (or discard) your edits in work/audacity first:
         git -C work/audacity add -A && git -C work/audacity commit -m \"Describe the change\"
       (files under muse/ are a separate repository: git -C work/audacity/muse ...)"
fi

export_patches() {
    local out="$1"; shift
    local tmp
    tmp="$(mktemp -d)"
    "$@" format-patch --quiet --no-numbered --zero-commit --no-signature --full-index --no-stat \
        --output-directory "$tmp" lt-base..HEAD -- . ':(exclude)muse' ':(exclude)muse_deps' >/dev/null
    mkdir -p "$out"
    find "$out" -maxdepth 1 -name '*.patch' -delete
    if [ -n "$(ls -A "$tmp")" ]; then mv "$tmp"/*.patch "$out"/; fi
    rmdir "$tmp"
    find "$out" -maxdepth 1 -name '*.patch' | wc -l | tr -d ' '
}

n_au="$(export_patches "$LT_ROOT/patches/audacity" wgit)"
n_mu="$(export_patches "$LT_ROOT/patches/muse" mgit)"

# Record that work/audacity now matches patches/ (see prepare-source.sh).
{
    echo "fingerprint=$(patches_fingerprint)"
    echo "audacity_head=$(wgit rev-parse HEAD)"
    echo "muse_head=$(mgit rev-parse HEAD)"
} > "$WORK_DIR/.prepared"

ok "Saved $n_au audacity and $n_mu muse patch(es)."
git -C "$LT_ROOT" status --short -- patches
