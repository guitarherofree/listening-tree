/*
 * Listening Tree — hands a downloaded update over to the installer script.
 *
 * Compiled into appshell by patches/audacity/0004-*.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */
#pragma once

#include <QString>

namespace lt::updater {
//! Starts packaging/macos/install-update.sh (bundled in the app at
//! Contents/Resources/listening-tree/) in the background. The script waits for
//! this process to exit, backs up settings, replaces the app bundle with the one
//! in `dmgPath`, and reopens the app.
//!
//! Returns false if the helper could not be started (not macOS, not running from
//! an .app bundle, or the helper is missing). The caller then falls back to
//! opening the disk image in Finder so the update can be installed by hand.
bool launchInstaller(const QString& dmgPath);
}
