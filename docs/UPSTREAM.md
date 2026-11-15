# Moving to a newer Audacity

Listening Tree is pinned to one Audacity release (`config/upstream.env`). Moving
to a newer one brings in Audacity's fixes and features while keeping your
changes.

## Steps

```sh
scripts/upgrade-audacity.sh                    # list recent Audacity releases
scripts/upgrade-audacity.sh Audacity-4.1.0     # move to one of them
```

The script:

1. makes sure `work/audacity` has no unsaved edits,
2. records the new tag and commit in `config/upstream.env`,
3. downloads that release and re-applies the branding and every patch,
4. warns if Audacity now builds with a different Qt version, or changed its
   update service (which `core/updater/appupdateservice.cpp` replaces).

If a patch no longer applies, fix it as described in "When a patch does not
apply" in [DEVELOPING.md](DEVELOPING.md), then run `scripts/save-patches.sh`.

Then:

```sh
scripts/build.sh --clean && scripts/run.sh     # try recording, playback, opening projects
git add -A && git commit -m "Move to Audacity 4.1.0"
```

and release it with a CHANGELOG entry such as "Now based on Audacity 4.1.0"
(a minor version step, e.g. 0.3.0 → 0.4.0).

If Audacity changed its Qt version, update `QT_VERSION` (and `QT_MODULES` if
upstream's list changed) in `config/upstream.env` to match
`work/audacity/.github/workflows/au4_build_macos.yml`, then run
`scripts/bootstrap.sh`.

## Things to know

- **Project files.** Each Audacity version can open projects saved by older
  ones. Opening a project in a newer Listening Tree may upgrade it so older
  versions can't open it, as in Audacity.
- **Pre-releases.** Audacity also tags alphas and betas (`Audacity-4.1.0-beta-1`).
  They work with the script, but stay on final releases for everyday use.
- **What Listening Tree changes in Audacity**, for reviewing upstream changes:
  `patches/audacity/` (name and version, About and splash, feature hook,
  installing updates, update preferences, shortcuts, startup, toolbar, recording and
  format defaults; see the list in DEVELOPING.md), `patches/muse/` (updater wiring),
  `branding/overlay/` (replaced images), and `core/updater/appupdateservice.cpp`
  (replaces `muse/framework/update/internal/appupdateservice.cpp`).

## License obligations

Audacity is licensed under the GPL version 3. If you give the app to anyone
else, you must also offer them the corresponding source code; this repository
(the pinned Audacity release plus `patches/`, `core/`, `features/` and the
scripts) is that source, so making it available to them covers it. The name
"Audacity" and its logo are trademarks, so keep Listening Tree's own name and
icon, and keep crediting Audacity in the About box.
