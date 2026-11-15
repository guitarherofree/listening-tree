# Building Listening Tree

## What you need

- A Mac with **macOS 13 or later** (Apple Silicon or Intel).
- **Xcode's command-line tools**: `xcode-select --install`. The full Xcode app
  (version 26 or later) is optional; with it, builds also get the new-style
  app icon from Xcode's icon compiler, and without it they use a prebuilt one.
- **About 25 GB of free disk space** (Qt, the Audacity source and build files).
- An internet connection for the first build (Qt, Audacity and its libraries are downloaded).

Everything else is installed into `.tools/` inside this folder by the bootstrap
script, so nothing on the rest of your Mac changes.

## First build

```sh
cd ~/ListeningTree
scripts/bootstrap.sh --with-gh   # CMake, Ninja, Qt 6.10 (about 1.5 GB) and the GitHub CLI
scripts/build.sh                 # 30–60 minutes the first time
scripts/run.sh                   # opens the app, with its log in the terminal
```

Run `brew install ccache` too if you use Homebrew: it makes later full rebuilds
(after `--clean`, or after moving to a newer Audacity) much faster.

## Development builds and release builds

| | `scripts/build.sh` | `scripts/build.sh --release` |
|---|---|---|
| Use it for | Trying changes | Packaging a version to publish |
| Output | `work/install-dev-arm64/audacity.app` | `work/install-release-arm64/audacity.app` |
| Settings | Its own ("ListeningTreeDev"), so experiments never touch your installed app's settings | The real ones, same as the installed app |
| Title bar | "Listening Tree dev" | "Listening Tree" |

Each kind has its own build folder, so switching between them doesn't force a rebuild.
After the first build, rebuilding only recompiles what changed (seconds to a few minutes).

Useful options:

- `--arch universal` builds for both Apple Silicon and Intel Macs (slower; `arm64` is the default on Apple Silicon).
- `--clean` deletes the build folder first (a full rebuild).
- `--skip-prepare` builds `work/audacity` as it is, without syncing it with `patches/`.

To build and package a release disk image: `scripts/build.sh --release && scripts/package.sh`.
The result goes to `dist/`. You normally don't do this by hand; `scripts/release.sh`
does it for you (see [RELEASING.md](RELEASING.md)).

## Building on GitHub instead

The **Build** workflow (GitHub › Actions › Build › Run workflow) makes a release
build on GitHub's Macs and attaches the disk image to the run for a week. While
the repository is private, macOS build time comes out of your monthly Actions
allowance at 10× the Linux rate (on the free plan about 200 macOS minutes a
month; a first build takes roughly an hour, later ones less thanks to the
compiler cache). Building on your Mac costs nothing.

Tick **preview** when running it to check a change to the look of the app without
a Mac at hand: the workflow then also starts the app on GitHub's Mac (allowing the
microphone first, and skipping the first-start plugin question), takes two
screenshots of the screen, and attaches them with the app's startup log. The
screenshots (as JPEG, base64) and the log are also printed in the step's own log,
between `=== BEGIN screen.jpg base64` and `=== END screen.jpg base64`, so they can
be read with `gh run view <run> --log` where attachments can't be downloaded.

Every push also runs the **Checks** workflow on a cheap Linux runner: it checks
that the patches still apply to the pinned Audacity release and runs the
installer tests.

## If something goes wrong

- **"Qt … not found"**: run `scripts/bootstrap.sh` (again).
- **Configuring failed**: the end of the log is printed; the full log is
  `work/configure-<dev|release>-<arch>.log`. A network hiccup while downloading
  Audacity's libraries is the most common cause; just run the build again.
- **A patch does not apply**: see "When a patch does not apply" in
  [DEVELOPING.md](DEVELOPING.md).
- **The app is "damaged" or "killed" when started**: the bundle's signature
  is broken, usually because files were changed after signing. Build again
  (the build re-signs the app at the end).
- **Start from scratch**: delete `work/` (and `.tools/` to reinstall the tools).
  Nothing in those folders is your own work unless you have unsaved edits in
  `work/audacity`. `scripts/prepare-source.sh` refuses to throw those away.
