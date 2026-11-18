# Changelog

Release notes for Listening Tree, newest first. When you publish a version,
`scripts/release.sh` uses its section below as the GitHub release notes, and the
app shows those notes in its update window, so write them for the person
updating: what's new, what changed, anything to watch out for.

Start each section with `## [x.y.z]` (a date after it is optional). Markdown
lists, **bold** and links show up nicely in the app.

## [Unreleased]

## [0.13.0] - 2026-11-18

**Record from any channel of your interface.**

- **The channel dropdown next to the input now lists every channel.** Pick a single channel (recorded as a mono track), a pair such as **Channels 3–4** (a stereo track), or all of the input's channels at once. Before, Listening Tree could only record the first one or two channels.
- On the Nano Cortex, channels 1–2 are the dry signal, so choose 3–4 (or whichever channels carry the processed sound) to record what you hear.
- Choosing a number of channels in Preferences › Audio starts from channel 1 again.

## [0.12.0] - 2026-11-15

**A toolbar laid out like Audacity 3's.**

- **Recording and playback meters** across the top, each with its level slider. The recording meter shows your input all the time, so you can set levels before you press Record. The mic button next to it has input monitoring and an option to stop metering when you're not recording. While the input is metered, macOS shows its microphone indicator.
- **Large transport buttons**: Pause, Play, Stop, Skip to start, Skip to end, Record and Loop.
- **Selection start and end** next to them (the gear switches the second one to the selection's length), and a **large playback time**.
- **Audio host, recording device, recording channels and playback device** in a row underneath.
- The zoom and editing buttons are no longer in the toolbar. Zoom with ↑ / ↓ or the View menu; the split tool is **S**, trim is **⌘T**, and silence is in the Edit menu. The clip gain and spectrogram buttons are gone.
- The selection bar at the bottom of the window and the playback meter on the right are gone, since both are in the toolbar now.

## [0.11.0] - 2026-11-15

**Recordings at the right sample rate, and H for the start.**

- **Recordings and exports are 48 kHz again.** Since 0.5.0, new projects recorded at 384 kHz by mistake. Your FM3 and Nano Cortex both run at 48 kHz, so the extra samples added nothing but file size (about 8 times bigger). New recordings are now 48 kHz, 24-bit, and Export starts at the rate of your audio. Takes you already recorded at 384 kHz still export at 384 kHz unless you pick 48000 Hz in the export window.
- **H takes you to the start of the recording**, like the Home key. It also works while playing: playback jumps back to the start and keeps going.

## [0.10.0] - 2026-11-15

**Export goes straight to your computer, and audio.com is gone.**

- **Export opens the export window right away.** It no longer asks whether to export to your computer or to audio.com.
- **No more audio.com (cloud) features.** Save to cloud, Update cloud audio preview and Share audio are gone from the File menu and from Preferences › Shortcuts. Saving a new project goes straight to choosing a place on your computer, and the Export page in Preferences (which only held those cloud questions) is gone.
- **Listening Tree no longer answers `audacity://` web links**, which were for signing in to audio.com. If you also have Audacity installed, those links go to Audacity.

## [0.9.0] - 2026-11-15

**Recording starts in the right place, and waveforms fill the track.**

- **Recording starts at the beginning, or right after what you've already recorded.** It no longer starts wherever the cursor is. In a new project it starts at 0:00; once there's a take, pressing Record again carries on from the end of it, on the same track.
- **Waveforms fill the track.** The view zooms in so the loudest part of a take reaches nearly the top and bottom of the track, so quiet recordings look as big as loud ones. It keeps up while you record, and refits when you stop. Only the view changes; the audio is untouched.
- **A new track fills the window.** It's as tall as the track area, so there's no empty space below it. You can still drag a track's bottom edge to resize it.
- **Back to the normal waveform shape.** The decibel scale from 0.8.0 is gone, since the zoom does the job better.

## [0.8.0] - 2026-11-15

**Bigger, cleaner waveforms.**

- **No more grid lines behind the tracks.** The track area is a plain background.
- **Waveforms are larger by default.** Tracks are about twice as tall, and the waveform is drawn on a decibel scale, so quiet recordings fill the track instead of a thin line in the middle. The audio itself is unchanged; this is only how it's drawn.
- **Prefer the usual waveform shape?** Turn on **View › Show vertical rulers**, click the scale at the left of a track and pick **Linear (amp)**. You can also drag a track's bottom edge to make it taller or shorter.

## [0.7.0] - 2026-11-15

- **No tracks panel on the left.** The window shows just your tracks. Track names, mute/solo, volume, pan and the realtime effects panel went with it; to add a track by hand, use **Tracks › Add new**.
- **After an update, the new version comes to the front.** Before, it started behind your other windows, so it looked as if the old version was still running in the background.

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
