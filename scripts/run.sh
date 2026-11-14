#!/usr/bin/env bash
# Runs a build of Listening Tree from work/, with its log in this terminal.
#
#   scripts/run.sh             the development build (scripts/build.sh)
#   scripts/run.sh --release   the release build (scripts/build.sh --release)
#
# Any other arguments are passed to the app (for example a project to open).
# Development builds keep their own settings ("ListeningTreeDev"), so trying
# things here never changes the installed app's settings.

. "$(dirname "$0")/lib/common.sh"

MODE=dev
if [ "${1:-}" = "--release" ]; then MODE=release; shift; fi
APP="$WORK_DIR/install-$MODE-$(host_arch)/$BUILT_APP_NAME"
[ -d "$APP" ] || die "No $MODE build found. Run scripts/build.sh$([ "$MODE" = release ] && echo " --release") first."
exec "$APP/Contents/MacOS/audacity" "$@"
