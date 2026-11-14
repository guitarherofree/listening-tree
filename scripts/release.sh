#!/usr/bin/env bash
# Publishes a new version of Listening Tree as a GitHub release.
#
#   scripts/release.sh 0.2.0           build on this Mac and publish (free; about 5-15 minutes after the first build)
#   scripts/release.sh 0.2.0 --ci      let GitHub Actions build and publish (uses Actions minutes)
#
# Before running it:
#   1. Commit your changes on the main branch and push them.
#   2. Add a "## [0.2.0]" section to CHANGELOG.md describing the changes and commit it.
#      That text becomes the release notes shown in the app's update dialog.
#
# The script sets VERSION, commits "Release v0.2.0", tags v0.2.0, pushes both,
# and creates the release with the disk image. Installed copies of the app
# offer the update the next time they check (Help > Check for updates, or daily).
#
# Options:
#   --draft     create the release as a draft (not offered to the app until you publish it on GitHub)
#   --yes       don't ask for confirmation

. "$(dirname "$0")/lib/common.sh"

NEW=""
CI=0
DRAFT=0
YES=0
while [ $# -gt 0 ]; do
    case "$1" in
        --ci) CI=1 ;;
        --local) CI=0 ;;
        --draft) DRAFT=1 ;;
        --yes|-y) YES=1 ;;
        -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option: $1" ;;
        *) NEW="${1#v}" ;;
    esac
    shift
done

[ -n "$NEW" ] || die "Which version? For example: scripts/release.sh 0.2.0"
semver_ok "$NEW" || die "Versions look like 1.2.3 (or 1.2.3-beta.1 for a test release), not '$NEW'"
TAG="v$NEW"
use_tools
require_cmd gh "Install the GitHub CLI: scripts/bootstrap.sh --with-gh"
gh auth status >/dev/null 2>&1 || die "The GitHub CLI is not signed in. Run: gh auth login"

cd "$LT_ROOT" || exit 1
branch="$(git rev-parse --abbrev-ref HEAD)"
[ "$branch" = main ] || die "Releases are made from the main branch (you are on '$branch')."
[ -z "$(git status --porcelain)" ] || die "Commit or stash your changes first (git status shows uncommitted files)."
git fetch --quiet origin main --tags
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "Your main branch differs from GitHub's. Push or pull first."
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then die "Tag $TAG already exists."; fi

if [ "$NEW" != "$LT_VERSION" ]; then
    version_gt "$NEW" "$LT_VERSION" || die "$NEW is not newer than the current version $LT_VERSION."
fi
latest_tag="$(git tag --list 'v*' --sort=-v:refname | head -1)"
if [ -n "$latest_tag" ]; then
    version_gt "$NEW" "${latest_tag#v}" || die "$NEW is not newer than the latest release ${latest_tag}."
fi

NOTES="$(release_notes "$NEW")"
[ -n "$NOTES" ] || die "CHANGELOG.md has no notes for $NEW. Add a section that starts with:  ## [$NEW]"

prerelease=0
case "$NEW" in *-*) prerelease=1 ;; esac

echo
info "About to release $APP_NAME $NEW ($([ "$CI" = 1 ] && echo "built by GitHub Actions" || echo "built on this Mac"))"
printf '%s\n' "$NOTES" | sed 's/^/    /'
echo
if [ "$YES" = 0 ]; then
    printf 'Continue? [y/N] '
    read -r answer
    case "$answer" in y|Y|yes) ;; *) die "Cancelled" ;; esac
fi

restore_version() { git checkout -- VERSION 2>/dev/null || true; }

printf '%s\n' "$NEW" > VERSION
if [ "$CI" = 0 ]; then
    is_macos || { restore_version; die "Building needs macOS; use --ci to build on GitHub instead."; }
    trap restore_version EXIT
    ARCH="$(host_arch)"
    "$LT_ROOT/scripts/build.sh" --release --arch "$ARCH"
    "$LT_ROOT/scripts/package.sh" --arch "$ARCH"
    trap - EXIT
fi

[ "$NEW" = "$LT_VERSION" ] || git commit --quiet -m "Release $TAG" -- VERSION
git tag -a "$TAG" -m "$APP_NAME $NEW"
git push --quiet origin HEAD:main
git push --quiet origin "$TAG"
ok "Pushed $TAG"

if [ "$CI" = 1 ]; then
    gh workflow run release.yml --repo "$GITHUB_REPO" --ref "$TAG" -f tag="$TAG" -f draft="$([ "$DRAFT" = 1 ] && echo true || echo false)"
    ok "GitHub Actions is building the release. Follow it with:  gh run watch --repo $GITHUB_REPO"
    exit 0
fi

flags=(--repo "$GITHUB_REPO" --title "$APP_NAME $NEW" --notes-file "$DIST_DIR/release-notes-$NEW.md" --verify-tag)
[ "$DRAFT" = 1 ] && flags+=(--draft)
[ "$prerelease" = 1 ] && flags+=(--prerelease)
gh release create "$TAG" "$DIST_DIR/$APP_ARTIFACT_PREFIX-$NEW-$ARCH.dmg" "$DIST_DIR/$APP_ARTIFACT_PREFIX-$NEW-$ARCH.dmg.sha256" "${flags[@]}"
ok "Released $APP_NAME $NEW: https://github.com/$GITHUB_REPO/releases/tag/$TAG"
