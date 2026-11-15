# Changelog

Release notes for Listening Tree, newest first. When you publish a version,
`scripts/release.sh` uses its section below as the GitHub release notes, and the
app shows those notes in its update window, so write them for the person
updating: what's new, what changed, anything to watch out for.

Start each section with `## [x.y.z]` (a date after it is optional). Markdown
lists, **bold** and links show up nicely in the app.

## [Unreleased]

## [0.6.0] - 2026-11-14

**A cleaner window.**

- **The top toolbar line is gone** (Audio setup, Share audio, Get effects, and the Workspace and Undo/Redo buttons on its right). Pick devices with the Input and Output dropdowns; recording channels and the audio host are in **Preferences › Audio**; undo is still **Z** / **⌘Z** and in the Edit menu.
- **The Add track button is hidden.** Recording makes its own track; to add one by hand, use **Tracks › Add new**.

## [0.5.0] - 2026-11-14

**Toolbar, recording and format.**

- **Input and Output dropdowns in the toolbar.** Pick the device you record from and the one you listen through, right next to the meters. The snap control is gone from the toolbar.
- **Check for updates is in the File menu** (File › Check for updates…). The button at the top of the window is gone.
- **Recording again picks up where you stopped.** After you stop, the playhead sits at the end of the take; press R and the next take continues from there on the same track. Click elsewhere first to record somewhere else.
- **No empty lined area below your tracks.** The lined canvas ends at the last track.
- **Recording format follows your interface.** With a Fractal FM3 connected (or else a Neural DSP Nano Cortex), new projects are 48 kHz, 24-bit, the best both record over USB. You can still change it in Preferences › Audio.
- **Exports default to WAV, 24-bit**, at the project's sample rate.

## [0.4.0] - 2026-11-14

**Listening Tree now opens ready to record.**

- Every launch starts in a new, empty project, so you can press **R** straight away. The welcome dialog and the first-launch setup are gone (theme, clip style and layout can still be changed in **Preferences**).
- The Home screen with its project list is gone. Open projects with **File › Open** or **File › Open recent**. Opening a project or dropping in an audio file uses the empty project's window instead of opening a second one.
- **File › Close** leaves you in a fresh, empty project. Quitting or closing an empty project you never touched no longer asks you to save it.
- If an update check fails, the message now says why (for example, a GitHub token that can't read the repository) instead of "Cannot connect to server".

## [0.3.0] - 2026-11-14

**New keyboard shortcuts.** Click in the track area first so the keys go to your project.

| Key | Does |
|---|---|
| R | Record |
| Space | Play / stop (also stops recording) |
| Z | Undo (⌘Z still works) |
| Delete | Delete the selection |
| ↑ / ↓ | Zoom in / zoom out on the waveform |
| ← / → | Move the playhead along the track; while playing, jump back or forward |
| I | Import audio (⌘⇧I still works) |
| E | Export audio (⌘⇧E still works) |

Four commands that used these keys moved: going to the track above or below is now ⌘⌥↑ / ⌘⌥↓, the effects panel is ⇧E, "select at zero crossings" is ⌥Z, and "set loop region in/out" is ⌥I.

Every shortcut can be changed in **Preferences › Shortcuts**. If you had already changed some there, use **Reset to default** to pick up these.

## [0.2.0] - 2026-11-14

- **Check for updates from the main window.** A button next to the Home and Project tabs checks for a new version. When one is available it changes to **Update available**; click it to see what's new and install it. (**Help › Check for update** still works too.)

## [0.1.1] - 2026-11-14

A small update to confirm that in-app updates work.

- No changes to recording, editing or your settings. If this window appeared and the update installs, the update system is working.
- The guides now explain how to clone the private repository on a new Mac.

## [0.1.0] - 2026-11-14

The first version of Listening Tree: Audacity 4.0.2 under its own name, with updates from GitHub.

- Based on **Audacity 4.0.2**. Recording, editing, effects and export work as in Audacity 4.0.2.
- **In-app updates:** Listening Tree checks this project's GitHub releases once a day (and whenever you choose **Help › Check for update**), shows what's new, and installs the update when you say so. Projects and settings stay as they are, and settings are backed up before each update.
- Keeps its own settings, separate from any copy of Audacity on the same Mac.
- Anonymous usage statistics (sent to audio.com by Audacity) are turned off.
