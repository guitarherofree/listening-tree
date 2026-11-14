#!/usr/bin/env bash
# Moves Listening Tree to a newer Audacity release.
#
#   scripts/upgrade-audacity.sh                 list recent Audacity release tags
#   scripts/upgrade-audacity.sh Audacity-4.1.0  rebase the patches onto that release
#
# What it does:
#   1. checks that work/audacity has no unsaved changes,
#   2. records the new tag and commit in config/upstream.env,
#   3. rebuilds work/audacity from the new release and re-applies the patches.
# If a patch no longer applies, it stops and tells you how to fix it
# (see "Moving to a newer Audacity" in docs/UPSTREAM.md). Afterwards: build,
# test, check the Qt version upstream uses, and commit.

. "$(dirname "$0")/lib/common.sh"

TAG="${1:-}"
if [ -z "$TAG" ]; then
    info "Recent Audacity releases (current: $AUDACITY_TAG)"
    git ls-remote --tags --refs "$AUDACITY_GIT_URL" 'Audacity-*' | sed 's|.*refs/tags/||' \
        | sort -V | tail -15
    exit 0
fi

commit="$(git ls-remote "$AUDACITY_GIT_URL" "refs/tags/$TAG^{}" | cut -f1)"
[ -n "$commit" ] || commit="$(git ls-remote "$AUDACITY_GIT_URL" "refs/tags/$TAG" | cut -f1)"
[ -n "$commit" ] || die "No tag '$TAG' in $AUDACITY_GIT_URL"
[ "$commit" != "$AUDACITY_COMMIT" ] || die "Already on $TAG"

# Refuse to throw away edits that are not saved as patches yet.
if [ -d "$SRC_DIR/.git" ]; then
    "$LT_ROOT/scripts/prepare-source.sh" --quiet >/dev/null 2>&1 || true
    if [ -n "$(wgit status --porcelain --ignore-submodules=all)" ] || [ -n "$(mgit status --porcelain)" ]; then
        die "work/audacity has uncommitted edits. Commit them and run scripts/save-patches.sh first."
    fi
fi

old_tag="$AUDACITY_TAG"
old_muse="$(mgit rev-parse -q --verify lt-upstream 2>/dev/null || true)"
sed -i.bak -e "s|^AUDACITY_TAG=.*|AUDACITY_TAG=\"$TAG\"|" -e "s|^AUDACITY_COMMIT=.*|AUDACITY_COMMIT=\"$commit\"|" \
    "$LT_ROOT/config/upstream.env"
rm -f "$LT_ROOT/config/upstream.env.bak"
info "config/upstream.env now pins $TAG ($commit)"

# The checks in prepare-source.sh compare against the stamp of the old tree; we just verified it is saved.
rm -f "$WORK_DIR/.prepared"
if "$LT_ROOT/scripts/prepare-source.sh"; then
    ok "All patches apply to $TAG."
else
    warn "Fix the conflicts as described above. When every patch is applied, run scripts/save-patches.sh."
    exit 1
fi

upstream_qt="$(sed -n "s/^ *version: '\([0-9.]*\)'.*/\1/p" "$SRC_DIR/.github/workflows/au4_build_macos.yml" | head -1)"
if [ -n "$upstream_qt" ] && [ "$upstream_qt" != "$QT_VERSION" ]; then
    warn "Upstream now builds with Qt $upstream_qt (config/upstream.env has $QT_VERSION). Update QT_VERSION and run scripts/bootstrap.sh."
fi
# core/updater/appupdateservice.cpp replaces upstream's file; flag upstream changes to it.
new_muse="$(mgit rev-parse lt-upstream)"
if [ -n "$old_muse" ] && [ "$old_muse" != "$new_muse" ] && mgit fetch --quiet --depth 1 origin "$old_muse" 2>/dev/null; then
    if ! mgit diff --quiet "$old_muse" "$new_muse" -- framework/update/internal/appupdateservice.cpp framework/update/internal/appupdateservice.h; then
        warn "Upstream changed its update service. Check whether core/updater/appupdateservice.cpp needs the same changes:
         git -C work/audacity/muse diff $old_muse $new_muse -- framework/update/internal/"
    fi
fi

echo
echo "Next:"
echo "  1. scripts/build.sh --clean && scripts/run.sh   and try the app"
echo "  2. Add a CHANGELOG.md entry (\"Now based on Audacity ${TAG#Audacity-}\", was ${old_tag#Audacity-}), commit, and release."
