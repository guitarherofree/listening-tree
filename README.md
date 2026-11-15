# Listening Tree

A macOS audio recorder and editor built from [Audacity](https://www.audacityteam.org/)'s
source code, with its own name, settings and update channel. It is a base for
custom recording features. This first version is Audacity 4.0.2 plus an
in-app updater that installs new versions published on this repository's
GitHub Releases page.

## Quick start (on your Mac)

The repository is private, so git has to be signed in to GitHub first (once per Mac):
`brew install gh && gh auth login --git-protocol https --web`, or clone it with GitHub Desktop.

```sh
git clone https://github.com/guitarherofree/listening-tree.git ~/ListeningTree
cd ~/ListeningTree
scripts/bootstrap.sh --with-gh   # one time: CMake, Ninja, Qt and the GitHub CLI, into .tools/
scripts/build.sh                 # development build (first time 30–60 min)
scripts/run.sh                   # start it
```

To install a published version: `scripts/install.sh --latest`. After that the app
updates itself: it checks once a day, and the **Check for updates** button in
the main window (next to the Home and Project tabs) checks right away.

## How this repository is organized

Audacity's source is **not** copied into this repository. Instead it records
which Audacity release to start from and what to change in it:

| Path | What it is |
|---|---|
| `config/upstream.env` | The Audacity release Listening Tree is built from (now `Audacity-4.0.2`), and the Qt version |
| `config/app.env` | App name, bundle ID, settings names, GitHub repository for updates |
| `VERSION` | Listening Tree's own version (separate from Audacity's) |
| `CHANGELOG.md` | Release notes; each version's section is shown in the app's update window |
| `patches/` | Small, numbered edits to Audacity (`patches/audacity/`) and its MuseScore framework (`patches/muse/`) |
| `branding/` | Icon, splash screen and About banner (`make-branding.py` regenerates `branding/overlay/`) |
| `core/updater/` | The GitHub Releases updater (replaces Audacity's update service in the build) |
| `features/` | Your own feature modules; switch them on and off in `features/enabled.txt` |
| `cmake/` | Build settings that apply the names and version from `config/` |
| `packaging/macos/install-update.sh` | Installs a downloaded update after the app quits |
| `scripts/` | Everything you run: bootstrap, build, run, package, install, release, patch tools |
| `.github/workflows/` | Checks on every push; build and release on GitHub's Macs when you ask |
| `work/`, `dist/`, `.tools/` | Generated locally and not committed: the patched source, builds, packages, tools |

`scripts/prepare-source.sh` (run automatically by `build.sh`) downloads the
pinned Audacity release into `work/audacity` and applies the branding and
patches, one git commit per patch. Changing Audacity code means editing there
and saving the result back into `patches/`. See [docs/DEVELOPING.md](docs/DEVELOPING.md).

## Documentation

- [Building](docs/BUILDING.md): requirements, first build, everyday builds, problems
- [Making changes](docs/DEVELOPING.md): editing Audacity code, adding and removing features
- [Releasing](docs/RELEASING.md): publishing a new version on GitHub
- [Updating the app](docs/UPDATING.md): how the updater works, the GitHub token for a private repository, installing by hand, going back a version
- [Moving to a newer Audacity](docs/UPSTREAM.md)

## License and name

Listening Tree is a modified version of Audacity and, like Audacity, is free
software under the GNU General Public License version 3 (see `LICENSE`).
"Audacity" is a trademark of Muse Group, which is why this app has its own name
and icon. The About box credits Audacity and its authors.
