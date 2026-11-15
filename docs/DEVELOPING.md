# Making changes

Listening Tree is Audacity plus a list of changes. There are three places a
change can live, from most to least separate from Audacity's own code:

1. **A feature** in `features/`: new code in its own module. Best for new
   functionality (custom recording tools, new windows, new effects). You can
   switch a feature off without touching anything else.
2. **Listening Tree's core** in `core/` and `cmake/`: code that replaces or
   extends a specific part of Audacity (today: the updater and the app's
   identity), wired in by a small patch.
3. **A patch** in `patches/`: a direct edit to Audacity's files. Needed when
   existing behaviour has to change. Keep patches small and focused so they
   carry over to newer Audacity releases easily.

## Where the code is

`scripts/prepare-source.sh` (also run by every `scripts/build.sh`) creates
`work/audacity`:

```
work/audacity            Audacity at the pinned release, as a git repository
  ├─ tag lt-upstream     the untouched release
  ├─ tag lt-base         + the branding overlay (icon, splash, About banner)
  └─ branch listening-tree, one commit per file in patches/audacity/
work/audacity/muse       the MuseScore framework Audacity is built on (its own git repository)
  └─ branch listening-tree, one commit per file in patches/muse/
```

Audacity 4 is organized into modules under `work/audacity/src/`: `record`,
`playback`, `trackedit`, `projectscene` (the track view), `effects`,
`importexport`, `appshell` (windows and menus), `preferences` and so on. Most
of the audio engine still comes from Audacity 3 under `work/audacity/au3/`.
QML files (`*.qml`) describe the user interface; C++ does the work.

## Changing Audacity's code (a patch)

```sh
scripts/prepare-source.sh                 # make sure work/audacity matches patches/
# edit files in work/audacity …
scripts/build.sh && scripts/run.sh        # try it
git -C work/audacity add -A
git -C work/audacity commit -m "Listening Tree: what this change does"
scripts/save-patches.sh                   # writes patches/audacity/NNNN-*.patch
git add patches && git commit -m "…"      # commit the patch in this repository
```

- Files under `work/audacity/muse/` belong to the framework repository: commit
  them with `git -C work/audacity/muse …`; they are saved to `patches/muse/`.
- To change an existing patch rather than add one, amend or fix up the commit
  in `work/audacity` (for example `git -C work/audacity rebase -i lt-base`),
  then run `scripts/save-patches.sh` again. The `patches/` folders are always
  rewritten to match the commits exactly.
- `prepare-source.sh` will not discard edits that are not saved as patches
  yet. `--force` does discard them.
- Don't edit the branding files in `work/audacity` directly; change
  `branding/make-branding.py`, run it, and commit `branding/`.

## Adding a feature

1. Copy `features/_template` to `features/<your-feature>` and rename the
   target, class and namespace in its `feature.cmake`, `CMakeLists.txt` and
   source files.
2. Add the folder name to `features/enabled.txt`.
3. `scripts/build.sh` builds it and the app creates the module at startup.
   Check the terminal output of `scripts/run.sh` for the template's
   "feature loaded" log line to confirm it's wired in.

A feature module is the same kind of module as Audacity's own (`src/record`,
`src/playback` …), so it can use their services. For example, the recording
service is `au::record::IRecordController` (in `src/record/`). Look at how an
existing module gets things (`muse::GlobalInject<…>` / `muse::ContextInject<…>`) and
registers actions, menus and QML pages, and do the same.

To leave a feature out, delete or comment out its line in `enabled.txt`
(its code stays). To remove it for good, delete its folder too.

## When a patch does not apply

This happens when Audacity changed the same lines, usually after moving to a
newer Audacity (`scripts/upgrade-audacity.sh`). `prepare-source.sh` stops with
git's message and leaves the half-applied patch in `work/audacity`:

```sh
git -C work/audacity status               # files with conflicts are listed
# open them, keep the intended change, remove the <<<<<<< ======= >>>>>>> markers
git -C work/audacity add -A
git -C work/audacity am --continue        # applies the remaining patches
scripts/save-patches.sh                   # saves the updated patches
```

(For a patch in `patches/muse/`, use `git -C work/audacity/muse …`.) To give up
on a patch instead: `git -C work/audacity am --skip`, then save.

## Default keyboard shortcuts

The default shortcuts are listed in `work/audacity/src/app/configs/data/shortcuts.xml`
(one `<SC>` entry per command; `Ctrl` there means ⌘ on a Mac). Listening Tree's
changes to it are in `patches/audacity/0007-Listening-Tree-default-keyboard-shortcuts.patch`;
edit the file in `work/audacity`, commit, and run `scripts/save-patches.sh` as for
any patch. When a key is used by two commands, the one whose context is more
specific wins (a key for "project focused" beats one for "any"), so give a key
to only one command per context. Users can still change every shortcut in
Preferences › Shortcuts; their changes are stored separately and win over the defaults.

## The version number

`VERSION` holds Listening Tree's own version (`MAJOR.MINOR.PATCH`). It is what
the app, its About box and the updater show and compare. Audacity's version
(4.0.2) stays inside the build because Audacity's code uses it to decide which
project files it can open. `scripts/release.sh` updates `VERSION` for you.

## Working with Claude

The scripts that manage the source (`prepare-source.sh`, `save-patches.sh`,
`upgrade-audacity.sh`) and the tests (`tests/test-install-update.sh`) also run
on Linux, so a cloud session can prepare and check patches. Building the app
needs a Mac, either yours or GitHub's (the Build workflow).
