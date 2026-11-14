#!/usr/bin/env bash
# Packages a release build into a disk image for GitHub Releases.
#
#   scripts/package.sh [--arch arm64|x86_64|universal]
#
# Needs a release build first (scripts/build.sh --release). Writes to dist/:
#   ListeningTree-<version>-<arch>.dmg          the disk image the updater installs
#   ListeningTree-<version>-<arch>.dmg.sha256   its checksum
#   release-notes-<version>.md                  this version's section of CHANGELOG.md

. "$(dirname "$0")/lib/common.sh"
. "$(dirname "$0")/lib/sign.sh"

ARCH="$(host_arch)"
while [ $# -gt 0 ]; do
    case "$1" in
        --arch) ARCH="$2"; shift ;;
        -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

is_macos || die "Packaging needs macOS."
BUILT="$WORK_DIR/install-release-$ARCH/$BUILT_APP_NAME"
[ -d "$BUILT" ] || die "No release build for $ARCH. Run: scripts/build.sh --release --arch $ARCH"

built_version="$(plutil -extract CFBundleShortVersionString raw -o - "$BUILT/Contents/Info.plist")"
[ "$built_version" = "${LT_VERSION%%-*}" ] || die "The release build is version $built_version but VERSION says $LT_VERSION. Rebuild: scripts/build.sh --release"

STAGING="$DIST_DIR/staging-$ARCH"
APP="$STAGING/$APP_BUNDLE_NAME"
DMG="$DIST_DIR/$APP_ARTIFACT_PREFIX-$LT_VERSION-$ARCH.dmg"

info "Preparing $APP_BUNDLE_NAME"
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$BUILT" "$APP"
find "$APP/Contents" -type d -name '*.dSYM' -prune -exec rm -rf {} +

# Prebuilt libraries can be universal; keep only the slice for this package's CPU.
if [ "$ARCH" != universal ]; then
    find "$APP/Contents" -type f -print0 | while IFS= read -r -d '' f; do
        archs="$(lipo -archs "$f" 2>/dev/null)" || continue
        if [ "$archs" != "$ARCH" ] && case " $archs " in *" $ARCH "*) true ;; *) false ;; esac; then
            lipo "$f" -thin "$ARCH" -output "$f.thin"
            chmod "$(stat -f '%Lp' "$f")" "$f.thin"
            mv -f "$f.thin" "$f"
        fi
    done
fi

[ -x "$APP/Contents/Resources/listening-tree/install-update.sh" ] || die "The update helper is missing from the build"
sign_app "$APP" "$SRC_DIR/buildscripts/packaging/MacOS/macosx_entitlements.plist" hardened

info "Creating $(basename "$DMG")"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG" "$DMG.sha256"
hdiutil create -quiet -volname "$APP_NAME $LT_VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG"
hdiutil verify -quiet "$DMG"
(cd "$DIST_DIR" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
rm -rf "$STAGING"

notes="$DIST_DIR/release-notes-$LT_VERSION.md"
release_notes "$LT_VERSION" > "$notes"
[ -s "$notes" ] || warn "CHANGELOG.md has no section for $LT_VERSION; the release would have no notes."

ok "$(du -h "$DMG" | cut -f1)  ${DMG#"$LT_ROOT"/}"
echo "   Install it here with:  scripts/install.sh ${DMG#"$LT_ROOT"/}"
