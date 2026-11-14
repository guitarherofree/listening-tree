# Releasing a new version

A release is a GitHub release on this repository, tagged `vX.Y.Z`, with a disk
image attached (`ListeningTree-X.Y.Z-arm64.dmg`). Installed copies of the app
look at the newest release, compare its version with their own, and offer it
with the release notes.

## Steps

1. **Commit and push** your changes on `main`.
2. **Write the release notes** in `CHANGELOG.md`: add a section at the top
   (under "Unreleased") and commit it:

   ```markdown
   ## [0.2.0] - 2026-12-01

   - New: …
   - Fixed: …
   ```

3. **Release:**

   ```sh
   scripts/release.sh 0.2.0
   ```

   It checks that everything is committed and pushed, shows the notes, asks
   for confirmation, then builds a release build on your Mac, packages it,
   sets `VERSION`, commits and tags `v0.2.0`, pushes, and creates the GitHub
   release with the disk image and its checksum.

4. **Check it:** open the release page it prints. In the installed app, choose
   **Help › Check for update**; it should offer the new version.

### Building on GitHub instead of your Mac

```sh
scripts/release.sh 0.2.0 --ci
```

does the same checks, pushes the tag, and starts the **Release** workflow,
which builds on GitHub's macOS runners and publishes the release. Follow it
with `gh run watch`. You can also start it from GitHub › Actions › Release ›
Run workflow: choose the branch (usually `main`) whose `VERSION` you want to
publish and type the tag (`v0.2.0`); the release creates the tag if it doesn't
exist yet. While the repository is private this uses macOS Actions minutes;
see [BUILDING.md](BUILDING.md).

## Version numbers

Use `MAJOR.MINOR.PATCH`:

- **PATCH** (0.2.0 → 0.2.1) for fixes,
- **MINOR** (0.2.1 → 0.3.0) for new features or a newer Audacity base,
- **MAJOR** (0.x → 1.0.0) when you consider it stable, or for big changes.

Every release must be newer than the last one; the script refuses otherwise.

**Test releases:** a version with a suffix, like `0.3.0-beta.1`, is published
as a GitHub *pre-release*. The app ignores pre-releases, so you can try a build
(`scripts/install.sh --version 0.3.0-beta.1`) without offering it to the
installed app. `--draft` creates a draft release that nobody sees until you
publish it on GitHub.

## Fixing a bad release

- **Not installed anywhere yet:** delete the release and its tag on GitHub
  (`gh release delete v0.2.0 --cleanup-tag`), fix, and release again.
- **Already installed:** release a fixed version with a higher number
  (0.2.1). To go back on your Mac in the meantime, see "Going back to an
  earlier version" in [UPDATING.md](UPDATING.md).

## What a release contains

| File | Purpose |
|---|---|
| `ListeningTree-X.Y.Z-arm64.dmg` | The app. The updater picks the disk image that matches the Mac (arm64, x86_64 or universal) |
| `…dmg.sha256` | Checksum, for checking by hand (`shasum -a 256 -c`). The updater uses the checksum GitHub records for each upload |
| Release notes | The `CHANGELOG.md` section, shown in the app's update window |

The app is signed "ad hoc" (no paid Apple Developer account). That's enough
for it to run and for updates to install, but the first install of a
downloaded copy needs one extra click (see [UPDATING.md](UPDATING.md)).
